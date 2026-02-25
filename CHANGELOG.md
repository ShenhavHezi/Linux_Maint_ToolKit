# Changelog

This project uses a lightweight changelog. Each release should add a short entry below using the template in `docs/RELEASE_TEMPLATE.md`.

## Unreleased

- (add changes here)

## 2026-02-25

- Release v0.2.6
- Added `run --only/--skip` targeting and `check --json` for automation.
- Added JSON redaction controls (`LM_REDACT_JSON`) across core outputs.
- Hardened SSH/summary validation (strict allowlists, retries, known_hosts pinning).
- Added inventory cache pruning, run tmpdir cleanup, and expanded fixtures/tests.
- Expanded operator docs and compatibility/runbook coverage.

## 2026-02-24

- Release v0.2.5
- Stabilized wrapper SKIP reasons (config_missing/baseline_missing + missing=... detail).
- Fixed diff --json to emit clean JSON-only output.
- Restored Python 3.6 compatibility for summary lint tooling.
- Fixed compat fixture naming in tests.

## 2026-02-24

- Release v0.2.4
- Expanded metrics JSON with severity totals, host counts, and per-monitor durations.
- Added JSON schemas/tests for diff and self-check outputs.
- Added per-monitor fixture coverage and stricter summary contract linting.
- Improved preflight compatibility warnings and help examples.
- Standardized RPM build outputs and documented install/layout/config templates.

## 2026-02-24

- Release v0.2.3
- (no notable changes)

## 2026-02-24

- Release v0.2.2
- Added SSH strict-mode quickstart and history usage tips in operator docs.
- Added seed_known_hosts tests and SSH allowlist/strict-mode examples in config template.
- Added history JSON contract version and run_index versioning with schema/test updates.
- Added docs-check to dev workflow and improved release-prep automation.

## 2026-02-24

- Release v0.2.1
- Added SSH known_hosts seeding helper and allowlist guidance for safer fleet SSH.
- Added run_index JSON schema + history contract notes, plus Prometheus contract notes.
- Added docs link check in CI and release-prep helper (`make release-prep`).
- Expanded operator docs: operations quickstart, upgrade/rollback guide, and top reasons quick reference.

## 2026-02-24

- Release v0.2.0
- Added `status --strict` validation and summary JSON schema validation in tests.
- Guarded JSON outputs from ANSI/control characters even when color is forced.
- Polished CLI output (report/trend/diff/status) and upgraded the run progress bar with percent + color cues.
- Added `status --group-by --top N` to cap group rows for large fleets.
- Added installed-mode sanity checks and a command contract checklist for core commands.
- Fixed summary reading/fixtures and hardened SSH known_hosts/dependency handling.

## 2026-02-22

- Release v0.1.8
- Added runtime threshold highlighting in `linux-maint runtimes` (human output).
- Added colorized non-zero counts in `linux-maint history` (text/compact) and `linux-maint status --last`.
- Cleaned stray artifacts in docs/reference.

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
