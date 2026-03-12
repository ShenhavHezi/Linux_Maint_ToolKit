# Release Notes v0.1.8

- Version: 0.1.8
- Date (UTC): 2026-02-22
- Git tag: v0.1.8

[Release history](https://github.com/ShenhavHezi/Linux_Maint_ToolKit/blob/main/docs/release_notes/README.md) · [Upgrade guide](https://github.com/ShenhavHezi/Linux_Maint_ToolKit/blob/main/docs/UPGRADE.md)

## Highlights
- Human output readability: added color cues across `check`, `diff`, `history`, `status --last`, and `runtimes`.
- Runtime threshold awareness: `runtimes` now highlights monitors that exceed configured warn thresholds.
- Documentation cleanup and improved reference guidance.

## Breaking changes
- None

## New features
- `linux-maint check` now prints colored OK/WARN/CRIT summaries for `config_validate` and `preflight`.
- `linux-maint diff` colorizes section headers and status transitions when color is enabled (respects `NO_COLOR`/`LM_FORCE_COLOR`).
- `linux-maint history` (text/compact) and `linux-maint status --last` colorize non-zero counts for faster scanning.
- `linux-maint runtimes` highlights monitors that exceed `MONITOR_RUNTIME_WARN_FILE` thresholds when color is enabled.

## Fixes
- Hardened diff color test to ignore inherited `NO_COLOR`.
- Added coverage for forced-color behavior in history, status, and runtimes outputs.

## Docs
- Reference: note runtime threshold highlighting and remove stray `active_line` artifacts.
- Clarified color conventions for non-JSON outputs.

## Compatibility / upgrade notes
- No action required.
