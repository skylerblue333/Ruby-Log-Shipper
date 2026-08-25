# Changelog

## Unreleased

### Added
- Native Ruby 3.3 JSONL log batching and HTTPS delivery.
- Bounded event/message/batch validation.
- HTTPS endpoint validation and deterministic SHA-256 batch IDs.
- Optional bearer token and explicit HTTP timeouts.
- Dry-run validation mode.
- Injectable transport tests plus CLI/container smoke gates.
- Non-root container packaging and security documentation.

### Changed
- Replaced the unrelated Python priority-job queue with the repository's intended Ruby log-shipping product while retaining Git history.
- Removed unrelated Python/Node runtime metadata from the active product path.

### Known limitations
- No durable spool, retries, compression, mTLS, multi-destination routing, metrics, HA, or verified production deployment.
