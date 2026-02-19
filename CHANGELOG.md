# Changelog

This project uses a lightweight changelog. Each release should add a short entry below using the template in `docs/RELEASE_TEMPLATE.md`.

## Unreleased

- (add changes here)

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
