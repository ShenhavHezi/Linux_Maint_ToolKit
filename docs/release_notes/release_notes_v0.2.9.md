# Release Notes v0.2.9

- Version: 0.2.9
- Date (UTC): 2026-03-02
- Git tag: v0.2.9

[Release history](README.md) · [Upgrade guide](../UPGRADE.md)

## Highlights
- Added a run concurrency lock with explicit override/timeout controls to prevent overlapping `linux-maint run` corruption.
- Introduced `run_id` + `schema_version` across summary/status/report/metrics JSON and run index entries.
- Expanded docs and operator workflows (custom monitors, fleet quickstart, TUI style guide, security response).

## Breaking changes
- None

## New features
- `linux-maint run --allow-concurrent` and `--lock-timeout N` for run locking behavior.
- Stable `run_id` and JSON schema versions in summary/status/report/metrics outputs and run index.
- `status`, `report`, `trend`: `--output <path>` for atomic file writes.
- `metrics --prom --output <path>` for Prometheus textfile collector workflows.
- `config --diff-defaults` to highlight deviations from shipped defaults.
- `list-monitors` now surfaces descriptions/config requirements from monitor headers.
- `pack-logs` adds optional GPG encryption (`--gpg`, `--gpg-recipient`, `--gpg-keep-plaintext`).
- TUI additions: About screen + end-of-run “next steps” hints.
- Run index age cap via `LM_RUN_INDEX_MAX_AGE_DAYS`.

## Fixes
- Guarded empty monitor resolution (fail fast when no monitors are selected).
- Summary line length and value caps to protect terminal/automation safety.
- Run index reader skips invalid JSONL records.
- Inventory export cache pruning is resilient even when host collection fails.
- Doctor JSON output now works reliably in repo mode.
- Updated release verification test to include BUILD_INFO/VERSION.

## Docs
- New `docs/CUSTOM_MONITORS.md` + `tools/new_monitor.sh` template generator.
- Added `docs/examples/fleet_quickstart/` and updated examples index.
- Added `docs/ARTIFACTS.md`, `docs/SECURITY_RESPONSE.md`, `docs/TUI_STYLE_GUIDE.md`.
- Updated reference/quick-reference for new flags and JSON schema changes.

## Compatibility / upgrade notes
- Summary JSON is now an object wrapper (`schema_version`, `run_id`, `meta`, `rows`); set `LM_JSON_LEGACY_LIST=1` for legacy list-only output.
- `LM_STRICT=1` now enforces weak SSH option guardrails and directory permission checks in doctor.
- `pack-logs --gpg` requires `gpg` and a valid recipient key.
- Run lock defaults to 60s; override with `--lock-timeout` or `LM_RUN_LOCK_TIMEOUT`.

## Checksums (if releasing a tarball)
- SHA256SUMS: c8f8a645e88d0f93140e8ccbcb4bd66c34f56528c3c7717d976b27877547298a  Linux_Maint_ToolKit-v0.2.9-1d15bae.tgz
