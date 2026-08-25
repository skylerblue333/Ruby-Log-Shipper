FROM ruby:3.3-alpine

WORKDIR /app
RUN addgroup -S app && adduser -S -G app app
COPY lib ./lib
COPY bin ./bin
RUN chmod +x /app/bin/sky-log-shipper
USER app
ENTRYPOINT ["ruby", "/app/bin/sky-log-shipper"]
