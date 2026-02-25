# Release Notes v0.2.6

## Version
- Version: 0.2.6
- Date (UTC): 2026-02-25
- Git tag: v0.2.6

## Highlights
- Added `run --only/--skip` targeting plus `check --json` for automation.
- Added JSON redaction controls (`LM_REDACT_JSON`) across core outputs.
- Hardened SSH/summary validation with strict allowlists, retries, and known_hosts pinning.

## Breaking changes
- None

## New features
- `linux-maint run --only/--skip` to target or exclude monitors during runs.
- `linux-maint check --json` for machine-readable preflight checks.
- JSON redaction (`LM_REDACT_JSON=1`) for report/trend/status/export/metrics outputs.
- SSH hardening knobs: `LM_SSH_ALLOWLIST_STRICT`, `LM_SSH_RETRY`, `LM_SSH_KNOWN_HOSTS_PIN_FILE`.
- Summary allowlist strict mode (`LM_SUMMARY_ALLOWLIST_STRICT=1`).
- Inventory cache pruning via `LM_INVENTORY_CACHE_MAX`.
- New Prometheus metric `linux_maint_monitor_host_count`.

## Fixes
- `linux-maint config --json` now emits JSON-only output when no config exists.
- Fixed summary diff variable shadowing and test matching edge cases.
- Synced summary contract monitors and fixtures for new monitors.

## Docs
- Added compatibility matrix and runbook coverage.
- Added operator examples and expanded operations guidance.

## Compatibility / upgrade notes
- `linux-maint config --json` now returns a JSON error object on missing config and exits 1.
- If you enable `LM_REDACT_JSON=1`, fields matching known secret patterns are redacted in JSON outputs.

## Checksums (if releasing a tarball)
- SHA256SUMS: 3c3908a763dbd6469af3222645dc4034f8456f427717630596323e8168a193ff  Linux_Maint_ToolKit-v0.2.6-af0da20.tgz
