# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/sky_log_shipper"

class SkyLogShipperTest < Minitest::Test
  EVENT = {
    "timestamp" => "2026-08-24T12:00:00Z",
    "level" => "INFO",
    "message" => "service started",
    "source" => "gateway",
    "attributes" => { "request_id" => "abc" }
  }.freeze

  def test_batch_is_deterministic
    first = SkyLogShipper::Batch.new([EVENT])
    second = SkyLogShipper::Batch.new([EVENT])
    assert_equal first.batch_id, second.batch_id
    assert_match(/\A[0-9a-f]{64}\z/, first.batch_id)
  end

  def test_rejects_invalid_endpoint_and_embedded_credentials
    assert_raises(SkyLogShipper::ValidationError) { SkyLogShipper::Endpoint.new("http://logs.example.test/v1") }
    assert_raises(SkyLogShipper::ValidationError) { SkyLogShipper::Endpoint.new("https://user:pass@logs.example.test/v1") }
  end

  def test_rejects_invalid_event_fields
    bad_level = EVENT.merge("level" => "TRACE")
    assert_raises(SkyLogShipper::ValidationError) { SkyLogShipper::Batch.new([bad_level]) }

    oversized = EVENT.merge("message" => "x" * (SkyLogShipper::MAX_MESSAGE_BYTES + 1))
    assert_raises(SkyLogShipper::ValidationError) { SkyLogShipper::Batch.new([oversized]) }
  end

  def test_ship_uses_injected_transport_and_returns_delivery
    calls = []
    transport = lambda do |endpoint:, batch:, token:|
      calls << [endpoint.uri.to_s, batch.batch_id, token]
      202
    end
    delivery = SkyLogShipper::Shipper.new(
      endpoint: "https://logs.example.test/v1/events",
      transport:,
      token: "token-value"
    ).ship([EVENT])

    assert_equal 202, delivery.status
    assert_equal 1, delivery.event_count
    assert_equal "https://logs.example.test/v1/events", calls[0][0]
    assert_equal "token-value", calls[0][2]
  end

  def test_rejects_empty_and_oversized_batches
    assert_raises(SkyLogShipper::ValidationError) { SkyLogShipper::Batch.new([]) }
    too_many = Array.new(SkyLogShipper::MAX_EVENTS + 1, EVENT)
    assert_raises(SkyLogShipper::ValidationError) { SkyLogShipper::Batch.new(too_many) }
  end
end
