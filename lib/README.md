# Library Layout

This directory holds the reusable shell libraries loaded by `bin/linux-maint` and the wrapper.

## Files

- `linux_maint.sh` — core shared shell helpers used across monitors and commands.
- `linux_maint_runtime.sh` — runtime/mode/path initialization.
- `linux_maint_admin.sh` — install, upgrade, and verification command helpers.
- `linux_maint_help.sh` — CLI help rendering.
- `linux_maint_tui.sh` — menu/TUI helpers and workflow rendering.
- `linux_maint_menu.sh` — menu routing, submenus, and workflow actions.
- `linux_maint_run.sh` — run argument parsing, resume handling, and run preflight helpers.
- `linux_maint_config.sh` — config inspection and check command helpers.
- `linux_maint_init.sh` — init/bootstrap command helpers.
- `linux_maint_doctor.sh` — doctor diagnostics and fix workflow helpers.
- `linux_maint_reporting.sh` — reporting and export command helpers.
- `linux_maint_advanced.sh` — plugin and advanced command helpers.
- `linux_maint_adminops.sh` — notify, ticket, audit-log, and cm-hook helpers.
- `linux_maint_history.sh` — history and run-index command helpers.
- `linux_maint_ops.sh` — baseline, tune, explain, and support-bundle helpers.
- `linux_maint_inspect.sh` — monitor catalog and summary-lint command helpers.
- `linux_maint_conf.sh` — installed-mode configuration loader/defaults.

## Design intent

The split keeps `bin/linux-maint` from becoming a monolith while preserving a Bash-only runtime.
