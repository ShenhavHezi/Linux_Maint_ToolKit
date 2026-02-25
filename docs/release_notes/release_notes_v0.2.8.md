# Release Notes v0.2.8

## Version
- Version: 0.2.8
- Date (UTC): 2026-02-25
- Git tag: v0.2.8

## Highlights
- Added an interactive TUI menu (`linux-maint menu`) with gum/dialog/whiptail support.
- Added a styled dashboard, tools/help menus, and live log/run views.
- Improved TUI progress output with a plain mode and forced progress rendering.

## Breaking changes
- None

## New features
- `linux-maint menu` for a guided TUI experience (optional; no impact on existing CLI flows).
- Sub-menus for Run, Reports, Tools & automation, Diagnostics, Config, and Help.
- Styled dashboard with problems + reasons tables and manual refresh (`r`).
- Live log tail screen and live run output view for interactive sessions.
- Menu label alignment + colorized tags for better readability.

## Fixes
- Added `LM_PROGRESS_MODE=plain` and `LM_PROGRESS_FORCE=1` support for clean TUI progress output.
- Improved ESC handling so sub-menus return correctly.
- Centered menu block inside the banner and stabilized spacing.

## Docs
- Added `linux-maint menu` to the main README and quick reference.

## Compatibility / upgrade notes
- TUI menu is optional; requires `gum` (preferred) or `dialog/whiptail`.
- Dashboard auto-refresh is off by default; enable with `LM_TUI_DASH_REFRESH=<seconds>`.
- Progress UI honors `LM_PROGRESS_MODE=plain` and `LM_PROGRESS_FORCE=1` for TUI runs.

## Checksums (if releasing a tarball)
- SHA256SUMS: (not generated for this release)
