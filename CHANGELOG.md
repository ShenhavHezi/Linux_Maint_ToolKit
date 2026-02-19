# Changelog

This project uses a lightweight changelog. Each release should add a short entry below using the template in `docs/RELEASE_TEMPLATE.md`.

## Unreleased

- (add changes here)

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
