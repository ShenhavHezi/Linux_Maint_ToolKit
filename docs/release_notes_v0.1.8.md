# Release Notes v0.1.8

## Version
- Version: 0.1.8
- Date (UTC): 2026-02-22
- Git tag: v0.1.8

## Highlights
- Human output readability: added color cues for runtime threshold breaches and non-zero counts.
- Cleaned stray artifacts in docs reference sections.

## Breaking changes
- None

## New features
- `linux-maint runtimes` highlights monitors that exceed `MONITOR_RUNTIME_WARN_FILE` thresholds when color is enabled.
- `linux-maint history` (text/compact) and `linux-maint status --last` now colorize non-zero counts in human output.

## Fixes
- Hardened diff color test to ignore inherited `NO_COLOR`.

## Docs
- Reference: note runtime threshold highlighting and remove stray `active_line` artifacts.

## Compatibility / upgrade notes
- No action required.

