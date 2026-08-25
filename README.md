# Sky Log Shipper Ruby

A dependency-light Ruby 3.3 JSONL log batch shipper for forwarding bounded structured events to a caller-configured HTTPS endpoint. This repository is an engineering-beta transport component, not a complete logging platform.

## Implemented behavior

- Native Ruby implementation using standard-library JSON, URI, Net::HTTP, time, and SHA-256 support.
- Reads newline-delimited JSON events from standard input.
- Requires timestamp, level, message, and source fields; optional attributes object.
- Supports `DEBUG`, `INFO`, `WARN`, and `ERROR` levels.
- Maximum 100 events per batch, 32 KiB per message, and 512 KiB encoded batch.
- HTTPS-only destination URLs with embedded credentials and fragments rejected.
- Deterministic SHA-256 batch identifier sent as `X-Sky-Batch-Id`.
- Optional bearer token through `SKY_LOG_TOKEN` without writing the token to output.
- Explicit connection/read timeouts and fail-closed handling of non-2xx responses.
- `--dry-run` mode validates and fingerprints input without making any network request.
- Injectable transport contract for deterministic tests.
- Non-root container packaging.

## Input example

```json
{"timestamp":"2026-08-24T12:00:00Z","level":"INFO","message":"gateway started","source":"gateway","attributes":{"region":"local"}}
```

Validate without delivery:

```bash
cat events.jsonl | ruby bin/sky-log-shipper --dry-run
```

Deliver:

```bash
export SKY_LOG_ENDPOINT='https://logs.example.test/v1/events'
export SKY_LOG_TOKEN='replace-with-runtime-secret'
cat events.jsonl | ruby bin/sky-log-shipper
```

## Verification

CI runs Ruby syntax checks, deterministic unit tests, dry-run CLI smoke tests, Docker build, non-root verification, and a container dry-run smoke test.

## Architecture

`SkyLogShipper::Batch` validates and canonically encodes events, `Endpoint` validates the HTTPS destination, `HttpTransport` owns bounded HTTP delivery, and `Shipper` composes them behind an injectable transport boundary. The CLI handles JSONL input and runtime configuration.

## SKYCOIN4444 integration

This component can forward structured logs from SKYCOIN4444 adapters or services to a separately operated HTTPS ingestion endpoint. Production use should add durable local spooling, retry/backoff policy, authenticated destination management, metrics, rate controls, secret management, and delivery observability rather than assuming a single synchronous POST is lossless.

## Status and limitations

**Status: Engineering Beta.** Code/container verification is being established; deployment is not verified.

The current implementation does not provide disk buffering, retries, compression, mTLS, certificate pinning, proxy support, destination allowlisting, multi-tenant routing, metrics, backpressure across producers, exactly-once delivery, guaranteed ordering across processes, HA, or a managed log backend. It should not be described as production-ready or lossless.

See `SECURITY.md` and `CHANGELOG.md` for operating boundaries and productization history.
