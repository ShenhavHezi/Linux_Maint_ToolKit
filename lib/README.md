# Library Layout

This directory holds the reusable shell libraries loaded by `bin/linux-maint` and the wrapper.

## Files

- `linux_maint.sh` — core shared shell helpers used across monitors and commands.
- `linux_maint_runtime.sh` — runtime/mode/path initialization and shared repo-vs-installed default path helpers.
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

`linux_maint_runtime.sh` is the canonical place for mode-sensitive path defaults. When a support lib
needs repo-vs-installed config, log, summary, state, or lock paths, prefer the runtime helpers there
instead of open-coding new `if [[ "$MODE" == "repo" ]]` blocks.

## Command ownership

- `linux_maint_help.sh`: top-level help rendering and command help pages
- `linux_maint_menu.sh` + `linux_maint_tui.sh`: `linux-maint menu`, menu routing, and TUI rendering
- `linux_maint_run.sh`: `linux-maint run` planning, resume, and execution helpers
- `linux_maint_config.sh`: `config` and `check`
- `linux_maint_init.sh`: `init`
- `linux_maint_doctor.sh`: `doctor`
- `linux_maint_reporting.sh`: `status`, `report`, `summary`, `metrics`, `trend`, `runtimes`, `export`, `diff`, `logs`
- `linux_maint_advanced.sh`: `plugin`, `serve`, `agent`, `policy`, `predict`, `ai-assist`, `federate`, `gate`
- `linux_maint_adminops.sh`: `notify`, `ticket`, `audit-log`, `cm-hook`
- `linux_maint_history.sh`: `history` and `run-index`
- `linux_maint_ops.sh`: `baseline`, `tune`, `explain`, `pack-logs`
- `linux_maint_inspect.sh`: `list-monitors` and `lint-summary`
- `linux_maint_admin.sh`: install/upgrade/verification dispatch glue

If a command needs a new behavior change, prefer extending its owning support lib before adding more
inline logic back into `bin/linux-maint`.
