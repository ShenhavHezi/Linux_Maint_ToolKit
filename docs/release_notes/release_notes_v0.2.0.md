# Release Notes v0.2.0

## Version
- Version: 0.2.0
- Date (UTC): 2026-02-24
- Git tag: v0.2.0

## Highlights
- Clearer operator output across `status`, `report`, `trend`, and `diff` with consistent color cues.
- Modernized run progress bar with percent complete, red→yellow→green status, and a friendly DONE summary.
- Stronger output contracts: strict `status` validation plus summary JSON schema coverage.

## Breaking changes
- None

## New features
- `linux-maint status --strict` optionally fails when summary lines are malformed or missing.
- `linux-maint status --group-by --top N` caps group rows while preserving stable ordering.
- Progress bar improvements for `linux-maint run`: percent complete, color ramp, and post‑run DONE info.
- Installed‑mode sanity test validates `/usr/local` layout, config, and writable dirs in CI.
- New core command contract checklist for `status`/`report`/`summary`/`diff`.

## Fixes
- Guarded JSON/summary outputs against ANSI/control characters even when color is forced.
- Summary JSON schema validation added to prevent drift in wrapper output.
- Hardened SSH known_hosts handling and remote dependency checks; improved summary fixture reading.

## Docs
- Added `docs/COMMAND_CONTRACT_CHECKLIST.md` and linked it from the docs index.
- Updated quick reference and reference docs for new flags.

## Compatibility / upgrade notes
- No action required.
