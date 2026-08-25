# frozen_string_literal: true

require "digest"
require "json"
require "net/http"
require "time"
require "uri"

module SkyLogShipper
  class Error < StandardError; end
  class ValidationError < Error; end
  class DeliveryError < Error; end

  MAX_EVENTS = 100
  MAX_MESSAGE_BYTES = 32 * 1024
  MAX_BATCH_BYTES = 512 * 1024
  LEVELS = %w[DEBUG INFO WARN ERROR].freeze

  Event = Data.define(:timestamp, :level, :message, :source, :attributes)
  Delivery = Data.define(:batch_id, :event_count, :status)

  def self.normalize_event(raw)
    raise ValidationError, "event must be an object" unless raw.is_a?(Hash)

    timestamp = raw.fetch("timestamp", nil)
    level = raw.fetch("level", nil)
    message = raw.fetch("message", nil)
    source = raw.fetch("source", nil)
    attributes = raw.fetch("attributes", {})

    begin
      parsed_time = Time.iso8601(timestamp.to_s).utc
    rescue ArgumentError
      raise ValidationError, "timestamp must be valid ISO-8601"
    end
    raise ValidationError, "level must be one of #{LEVELS.join(', ')}" unless LEVELS.include?(level)
    raise ValidationError, "message must be a non-empty string" unless message.is_a?(String) && !message.empty?
    raise ValidationError, "message is too large" if message.bytesize > MAX_MESSAGE_BYTES
    raise ValidationError, "source must be a bounded string" unless source.is_a?(String) && source.length.between?(1, 128)
    raise ValidationError, "attributes must be an object" unless attributes.is_a?(Hash)

    Event.new(
      timestamp: parsed_time.iso8601(6),
      level:,
      message:,
      source:,
      attributes:
    )
  end

  class Batch
    attr_reader :events, :batch_id, :body

    def initialize(events)
      raise ValidationError, "batch must contain 1-#{MAX_EVENTS} events" unless events.is_a?(Array) && events.length.between?(1, MAX_EVENTS)

      @events = events.map { |event| SkyLogShipper.normalize_event(event) }.freeze
      payload = {
        "events" => @events.map do |event|
          {
            "timestamp" => event.timestamp,
            "level" => event.level,
            "message" => event.message,
            "source" => event.source,
            "attributes" => event.attributes
          }
        end
      }
      @body = JSON.generate(payload).freeze
      raise ValidationError, "encoded batch is too large" if @body.bytesize > MAX_BATCH_BYTES

      @batch_id = Digest::SHA256.hexdigest(@body).freeze
    end
  end

  class Endpoint
    attr_reader :uri

    def initialize(value)
      @uri = URI.parse(value.to_s)
      unless @uri.is_a?(URI::HTTPS) && @uri.host && !@uri.host.empty? && @uri.userinfo.nil?
        raise ValidationError, "endpoint must be HTTPS and must not contain embedded credentials"
      end
      raise ValidationError, "endpoint fragments are not allowed" if @uri.fragment
    rescue URI::InvalidURIError
      raise ValidationError, "endpoint must be a valid HTTPS URL"
    end
  end

  class HttpTransport
    def initialize(open_timeout: 5, read_timeout: 10)
      @open_timeout = open_timeout
      @read_timeout = read_timeout
    end

    def call(endpoint:, batch:, token: nil)
      request = Net::HTTP::Post.new(endpoint.uri.request_uri)
      request["Content-Type"] = "application/json"
      request["User-Agent"] = "sky-log-shipper/1.0"
      request["X-Sky-Batch-Id"] = batch.batch_id
      request["Authorization"] = "Bearer #{token}" if token && !token.empty?
      request.body = batch.body

      http = Net::HTTP.new(endpoint.uri.host, endpoint.uri.port)
      http.use_ssl = true
      http.open_timeout = @open_timeout
      http.read_timeout = @read_timeout
      response = http.request(request)
      unless response.code.to_i.between?(200, 299)
        raise DeliveryError, "destination returned HTTP #{response.code}"
      end
      response.code.to_i
    rescue IOError, SystemCallError, Timeout::Error, SocketError => error
      raise DeliveryError, "delivery failed: #{error.class}"
    end
  end

  class Shipper
    def initialize(endpoint:, transport: HttpTransport.new, token: nil)
      @endpoint = Endpoint.new(endpoint)
      @transport = transport
      @token = token
    end

    def ship(events)
      batch = Batch.new(events)
      status = @transport.call(endpoint: @endpoint, batch:, token: @token)
      Delivery.new(batch_id: batch.batch_id, event_count: batch.events.length, status:)
    end
  end
end
