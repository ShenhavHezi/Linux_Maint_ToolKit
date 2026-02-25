# Release Notes v0.2.7

## Version
- Version: 0.2.7
- Date (UTC): 2026-02-25
- Git tag: v0.2.7

## Highlights
- Added `run --plan` (table + JSON) for dry-run scheduling previews.
- Added monitor discovery helpers (`list-monitors`, `lint-summary`).
- Added Prometheus last-run metrics plus stricter config/summary validations.

## Breaking changes
- None

## New features
- `linux-maint run --plan` and `linux-maint run --plan --json` for dry-run planning.
- `linux-maint list-monitors` for enumerating monitor scripts.
- `linux-maint lint-summary` for summary contract checks.
- Prometheus metrics include last-run exit code and timestamp.
- Config validation checks for world-writable config and pinned known_hosts files.
- Support for `LM_REDACT_JSON_STRICT` for stricter JSON redaction.
- Tarball bundles include integrity metadata and release verification checks.

## Fixes
- Strict JSON redaction now applies to export outputs consistently.
- Fixed `list-monitors` piping and `lint-summary` regex handling.
- Stabilized default monitor parsing and status table fixtures.

## Docs
- Added monitor coverage matrix and operator FAQ.
- Added contributors and artifacts reference docs.
- Expanded release notes index and reasons catalog.

## Compatibility / upgrade notes
- `config_validate.sh` now requires `stat` to detect world-writable config files.
- `LM_REDACT_JSON_STRICT=1` redacts sensitive fields in JSON outputs more aggressively.

## Checksums (if releasing a tarball)
- SHA256SUMS: (not generated for this release)
