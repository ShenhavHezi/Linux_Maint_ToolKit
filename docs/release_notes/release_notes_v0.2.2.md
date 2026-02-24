# Release Notes v0.2.2

## Version
- Version: 0.2.2
- Date (UTC): 2026-02-24
- Git tag: v0.2.2

## Highlights
- Clearer operator guidance for strict SSH mode and history usage.
- Stronger history/run index contracts with explicit versioning.
- Better DX with local docs-check and improved release-prep automation.

## Breaking changes
- None

## New features
- Strict SSH quickstart steps added to `docs/OPERATIONS.md`.
- History usage tips added to `docs/QUICK_REFERENCE.md`.
- `history_json_contract_version` added to `linux-maint history --json`.
- `run_index_version` added to `run_index.jsonl` entries.
- New `tests/seed_known_hosts_test.sh` and schema/test updates for history/run index.
- `make docs-check` and docs link check added to `tools/dev_check.sh`.
- `tools/release_prep.sh` now updates docs index pointers for release notes.

## Fixes
- None

## Docs
- Added SSH allowlist and strict-mode example settings to config template.
- Updated reference docs for new history/run index contracts.

## Compatibility / upgrade notes
- No action required.
