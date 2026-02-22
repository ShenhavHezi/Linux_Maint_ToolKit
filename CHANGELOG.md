# Changelog

This project uses a lightweight changelog. Each release should add a short entry below using the template in `docs/RELEASE_TEMPLATE.md`.

## Unreleased

- (add changes here)

## 2026-02-22

- Release v0.1.7
- Added strict run validation (`linux-maint run --strict`) and deterministic test mode (`LM_TEST_MODE=1`).
- Added structured `fix_actions` to `doctor --fix --json`.
- Added `status --group-by` and a one-screen `report --short`.
- Added expected-SKIPs banner for first-run guidance.
- Added `status --prom` and `metrics --json` snapshots (with schemas).
- Added `next_step=` hints for common `reason=` values.
- Added `linux-maint explain monitor <name>` and export allowlist support.
- Added SSH known_hosts mode toggle and pack-logs hash manifest.
- Added trend/runtimes JSON schemas and release draft workflow on tag push.

## 2026-02-22

- Release v0.1.6
- Added `linux-maint status --expected-skips` to show expected SKIPs for missing optional config.
- Smoke tests now use a summary fixture for summary noise lint (avoid long wrapper runs in CI).
- Added a quickstart banner to README for faster onboarding.
- Hardened `network_monitor` to validate targets/params and block unsafe inputs.
- Sanitized `user_monitor` baseline filenames to prevent host path traversal.
- Added Prometheus metric `linux_maint_last_run_age_seconds` (time since wrapper run).

## 2026-02-22

- Release v0.1.5
- Added CLI flags for progress control (`--progress|--no-progress`) on run/pack-logs/baseline.
- Added `linux-maint help <command>` and refined help/menu UX.
- Locked color precedence (`NO_COLOR` overrides `LM_FORCE_COLOR`) with tests.
- Added pack-logs redaction flags plus bundle metadata (`meta/bundle_meta.txt`).
- Expanded secret scan patterns for common token formats.
- Added JSON schema + contract versions for report/config; enhanced runtimes JSON with unit/source.
- Added release automation (`tools/release.sh`, `make release`).

## 2026-02-22

- Added progress bars for runs and support bundles; per-host progress for baseline updates.
- Polished CLI UX with colored section headers, clearer hints, and a quick-start menu.
- Added `LM_FORCE_COLOR` to force ANSI output even without a TTY.
- Expanded config/history/report output formatting for better readability.
- Updated tests to handle forced color and tightened header matching.

## 2026-02-19

- Added colorized CLI output for status/report with NO_COLOR/--no-color support.
- Added one-line summary command for cron/dashboards.
- Expanded help with examples and updated quick reference docs.
- Added tests covering report/summary output and no-color behavior.

## 2026-02-19

- Fixed wrapper skip gating so skipped monitors do not execute; wrapper skips now use host=runner.
- Hardened LM_SSH_OPTS validation in the library and added coverage.
- Improved quick-check reliability in restricted temp dir environments.
- Added remediation notes for common WARN/SKIP reasons and log retention guidance.
- Added make-tarball alias target for release builds.

## 2026-02-19

- Added dark-site tuning helper and baseline guidance, plus docs updates.
- Added new monitors: filesystem read-only, last-run age, and systemd timer.
- Reduced preflight noise and improved mount exclude handling.
- Fixed ports_baseline_monitor cleanup trap.
- Improved installed-run tune output and config loading.
- General CLI/docs UX improvements.

## 2026-02-18

- Added JSON schema validation for `status --json` and `doctor --json`.
- Added `linux-maint export --json` unified payload output.
- Added runtime warnings to status JSON and fix suggestions to doctor JSON.
- Docs improved with first-run expectations and example outputs.
