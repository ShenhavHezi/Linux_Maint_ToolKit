# Library Layout

This directory holds the reusable shell libraries loaded by `bin/linux-maint` and the wrapper.

## Files

- `linux_maint.sh` — core shared shell helpers used across monitors and commands.
- `linux_maint_runtime.sh` — runtime/mode/path initialization.
- `linux_maint_admin.sh` — install, upgrade, and verification command helpers.
- `linux_maint_help.sh` — CLI help rendering.
- `linux_maint_tui.sh` — menu/TUI helpers and workflow rendering.
- `linux_maint_reporting.sh` — reporting and export command helpers.
- `linux_maint_advanced.sh` — plugin and advanced command helpers.
- `linux_maint_conf.sh` — installed-mode configuration loader/defaults.

## Design intent

The split keeps `bin/linux-maint` from becoming a monolith while preserving a Bash-only runtime.

