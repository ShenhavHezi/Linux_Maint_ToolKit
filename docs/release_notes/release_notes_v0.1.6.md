# Linux Maintenance Toolkit v0.1.6

- Version: 0.1.6
- Date (UTC): 2026-02-22
- Git tag: v0.1.6

## Highlights
- Security hardening for network and user monitors.
- New Prometheus metric for last run age.
- UX and docs improvements, plus test suite stability fixes.

## Changes
- Security: validate `network_monitor` targets/params to block unsafe inputs and report invalid targets.
- Security: sanitize `user_monitor` baseline filenames to prevent host path traversal.
- Observability: add Prometheus metric `linux_maint_last_run_age_seconds`.
- Docs: document new metric and network target validation rules.
- Tests: tighten status/output assertions; use summary fixtures to reduce long runs.

## Notes
- Invalid `network_targets.txt` entries are now skipped and reported as `invalid_target` in alerts.
- Prometheus textfile output includes `linux_maint_last_run_age_seconds` (time since wrapper run).
