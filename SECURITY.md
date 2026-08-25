# Security Policy

Sky Log Shipper Ruby is an engineering-beta outbound transport component.

## Current boundary

The shipper only accepts HTTPS destinations, rejects URL-embedded credentials, bounds event/message/batch sizes, uses TLS through Ruby's Net::HTTP defaults, and never prints the optional bearer token. `--dry-run` performs validation without networking.

## Operating guidance

- Inject `SKY_LOG_TOKEN` at runtime through a secret manager or equivalent process environment; do not commit tokens.
- Restrict `SKY_LOG_ENDPOINT` to an approved ingestion service at deployment time.
- Treat logs as potentially sensitive and define a data-minimization/retention policy before forwarding them.
- Do not assume a successful HTTP response proves durable downstream storage.
- Add durable local spooling/retries before relying on the component where log loss is unacceptable.

## Unsupported claims

The repository does not provide mTLS, certificate pinning, durable queues, delivery retries, exactly-once semantics, tenant isolation, compliance certification, or verified production deployment.

## Reporting

Use GitHub private vulnerability reporting when enabled and avoid posting live credentials or sensitive log payloads in issues.
