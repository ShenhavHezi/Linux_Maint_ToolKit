# Release Notes v0.2.4

## Version
- Version: 0.2.4
- Date (UTC): 2026-02-24
- Git tag: v0.2.4

## Highlights
- Metrics JSON expanded with severity totals, host counts, and per-monitor durations.
- Summary contract tightened with duplicate/invalid reason checks; cert monitor now reports as `host=runner`.
- Added JSON schemas for diff/self-check plus fixture-driven monitor coverage.

## Breaking changes
- None

## New features
- `linux-maint metrics --json` now includes `severity_totals`, `host_counts`, and `monitor_durations_ms`.
- New JSON schemas and tests for `linux-maint diff --json` and `linux-maint self-check --json`.
- Added per-monitor fixture summary coverage for contract regressions.
- Added config templates for `monitor_timeouts.conf` and `monitor_runtime_warn.conf`.
- RPM build now copies outputs to `dist/rpm/` for consistent packaging artifacts.

## Fixes
- `lm_summary` now normalizes empty `reason=` tokens to `reason=unknown`.
- Preflight compatibility warnings now surface missing bash/core tools (stderr + log).

## Docs
- Documented installed file layout and config templates.
- Documented packaging outputs for tarball/RPM builds.
- Expanded CLI examples for run/report/trend/diff (color + no-color).

## Compatibility / upgrade notes
- `cert_monitor` now emits `host=runner` instead of `host=all`. Update any automation that filtered on `host=all`.

## Checksums (if releasing a tarball)
- SHA256SUMS: add12e96eebdfc703a7b335de0d25e111942267bbd7c2d28d61b013cf8125352  Linux_Maint_ToolKit-v0.2.4-77efb68.tgz
