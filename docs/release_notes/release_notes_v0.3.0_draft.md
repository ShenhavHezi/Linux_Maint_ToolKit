# Release Notes v0.3.0 (Draft)

## Highlights
- Expanded `linux-maint menu` into a guided operator UI with run wizard, status drilldown, and menu settings.
- Added post-run quick actions and support-bundle summaries to reduce operator follow-up steps.
- Added menu-focused regression tests for routing, shortcuts, settings persistence, and wizard flows.
- Added release-governance audit and wired release tooling to run checks by default.
- Expanded metrics JSON with slow-monitor rollups and seconds precision for observability.

## Menu UX changes
- Run menu adds `wizard` flow for selecting scope/targets/mode without manual flags.
- Reports menu adds `drilldown` flow with status/host/monitor/reason filters.
- Drilldown can now explain the top filtered problem in one step (reason + monitor).
- Config menu adds `settings` screen with optional persistence at `~/.config/linux-maint/menu.conf`.
- Main menu supports shortcuts (`r` run, `s` reports, `d` diagnostics, `h` help).
- Dashboard includes recent artifact paths/timestamps.
- Menu command execution now shows `Will run: ...` preview (can be disabled with `LM_TUI_PREVIEW=0`).

## New environment controls
- `LM_TUI_DEFAULT_STATUS_VIEW=table|compact`
- `LM_TUI_DEFAULT_PROBLEMS=<int>`
- `LM_TUI_DEFAULT_REASONS=<int>`
- `LM_TUI_PREVIEW=1|0`
- `LM_TUI_SHORTCUTS=1|0`

## Tests added
- `tests/menu_shortcuts_test.sh`
- `tests/menu_settings_roundtrip_test.sh`
- `tests/menu_run_wizard_test.sh`
- `tests/menu_settings_validation_test.sh`
- `tests/help_menu_command_test.sh`
- `tests/release_audit_test.sh`
- `tests/release_audit_make_target_test.sh`
- `tests/release_sh_checks_test.sh`
- `tests/status_prom_parse_safety_test.sh`
- `tests/menu_run_loop_continuation_test.sh`

## Release tooling
- New `tools/release_audit.sh` validates governance templates and release-notes references.
- `tools/release.sh` now runs `release_check` and `release_audit` by default (override with `--skip-checks`).

## Observability
- `linux-maint metrics --json` now includes:
  - `monitor_durations_seconds`
  - `slow_monitors_top` (default top 5; controlled by `LM_METRICS_TOP_SLOW=1..20`)
- `status --prom` now tolerates unreadable summary files and emits safe zero counts instead of crashing.
