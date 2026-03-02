# TUI Style Guide

This guide keeps the `linux-maint menu` experience consistent as new views are added.

## Colors

- Use semantic colors: OK=green, WARN=yellow, CRIT=red, UNKNOWN=magenta, SKIP=gray.
- Avoid bright flashing styles; keep contrast readable on light/dark terminals.
- Use `NO_COLOR`/`LM_NO_COLOR` to suppress ANSI output for logs.

## Layout

- Prefer a single banner and avoid reprinting it for sub-menus.
- Keep menu labels aligned and left-anchored for scanability.
- Use short, scannable section headers (1 line).
- Avoid dense multi-line blocks; show “more” via a view action instead.

## Output handling

- Use `tui_run_cmd` for command output capture and display.
- Use `tui_run_live` only for long-running commands (e.g., `run`).
- Keep stderr noise to a minimum; use friendly errors in `tui_msgbox`.
- Show a pre-execution preview (`Will run: ...`) for menu-triggered commands unless disabled.

## Interactions

- `Esc` or `q` should return to the previous menu (not exit).
- Confirm destructive actions with `tui_yesno`.
- Provide a short “next steps” hint after long runs.
- Keep keyboard shortcuts stable (`r/s/d/h` in main menu) and document them in labels.
- Guided flows (wizard/drilldown/settings) must always allow cancel/back without side effects.

## Backend support

- `gum` is preferred. `dialog`/`whiptail` should be functional fallbacks.
- Avoid hard dependencies; detect backend availability at runtime.
