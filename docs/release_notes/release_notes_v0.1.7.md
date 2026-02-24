# Release Notes

## Version
- Version: 0.1.7
- Date (UTC): 2026-02-22
- Git tag: v0.1.7

## Highlights
- Production hardening for summary output and validation, plus deterministic test mode.
- Operator UX improvements: grouped status summaries and one-screen reports.
- New automation outputs: Prometheus summary metrics and metrics snapshot JSON.

## Breaking changes
- None

## New features
- `linux-maint run --strict` and `LM_TEST_MODE=1` for validation and deterministic runs.
- `doctor --fix --json` now returns structured `fix_actions` entries.
- `status --group-by <host|monitor|reason>` for fleet grouping.
- `report --short` for a one-screen operator summary.
- Expected SKIPs banner for first-run guidance.
- `status --prom` (textfile metrics) and `metrics --json` snapshot.
- `next_step=` hints for common `reason=` values.
- `linux-maint explain monitor <name>` and export allowlist support.
- SSH known_hosts mode toggle and pack-logs hash manifest.
- Trend/runtimes JSON schemas; release draft workflow on tag push.

## Fixes
- Improved strict summary validation and wrapper behavior on malformed lines.

## Docs
- Updated reference docs and quick reference for new flags and contracts.
- Added/updated JSON schemas and release checklist notes.

## Compatibility / upgrade notes
- No action required. New features are additive.

## Checksums (if releasing a tarball)
- SHA256SUMS: (add during release build)
