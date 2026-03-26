# Release Notes v0.3.8

- Version: 0.3.8
- Date (UTC): 2026-03-26
- Git tag: v0.3.8
- Commit: ed4402b

[Release history](https://github.com/ShenhavHezi/Linux_Maint_ToolKit/blob/main/docs/release_notes/README.md) · [Upgrade guide](https://github.com/ShenhavHezi/Linux_Maint_ToolKit/blob/main/docs/UPGRADE.md)

## Summary

This release deepens baseline lifecycle workflows and exposes that state in the main operator surfaces.
Operators can now preview or apply recommended baseline refreshes, and `status` / `report` surface stale baseline and drift attention directly.
It also fixes a real baseline update bug in the baseline monitors and continues the CLI consistency work without changing existing JSON contract fields.

## Highlights

- Added `linux-maint baseline refresh --apply` with a no-surprises plan-first flow.
- Surfaced baseline lifecycle context directly in `status --json`, human `status`, and human `report`.
- Fixed baseline monitor update handling so `--update` now actually refreshes existing baselines.

## Operator impact

- `linux-maint baseline refresh --apply` now:
  - prints the selected refresh plan first
  - applies only recommended refresh commands
  - returns machine-readable apply results with `applied`, `blocked`, `failed`, and `result`
- `linux-maint status` and `linux-maint report` now show baseline lifecycle only when baseline data is meaningfully present.
- `status --json` gained a nested optional `baseline` object that reuses the existing baseline status contract.

## Upgrade and compatibility notes

- Breaking changes:
  - None
- Upgrade notes:
  - After upgrading, run `linux-maint baseline status` to review stale or drifted baselines before the next large fleet run.
  - `linux-maint status` and `linux-maint report` may now recommend `linux-maint baseline refresh --plan` when lifecycle attention is needed.
- Compatibility notes:
  - Existing `status --json` consumers remain compatible; the new `baseline` object is additive and optional.
  - `baseline refresh --plan --json` remains compatible and now optionally includes an additive `apply` block when `--apply --json` is used.

## Fixes

- Fixed a baseline lifecycle bug where the baseline monitors hardcoded `BASELINE_UPDATE=false`, which prevented `linux-maint baseline ... --update` from updating existing baselines correctly.
- Kept `baseline refresh --apply --json` machine-safe by suppressing nested baseline monitor stdout leakage into the JSON payload.
- Limited baseline lifecycle surfacing to meaningful states so `status` / `report` do not add noise when no baseline data exists yet.

## Docs and UX

- Updated quick reference and reference docs for `baseline refresh --apply`.
- Brought baseline lifecycle guidance into the same `Guidance` / `Summary` footer style used by the other polished human commands.

## Validation

- `bash tools/release_check.sh`
- `bash tools/release_audit.sh`
- `bash tests/smoke.sh`
- additional focused checks:
  - `bash tests/core/baseline_refresh_apply_test.sh`
  - `bash tests/reporting/status_baseline_lifecycle_test.sh`
  - `bash tests/reporting/report_baseline_lifecycle_test.sh`
  - `make quick-check`

## Release assets

- Tarball: `Linux_Maint_ToolKit-v0.3.8-ed4402b.tgz`
- SHA256SUMS: 6c006423db20b5868d409c2e01ad23fa08f7f52bd21fb597c71f3e4c598e4c07  Linux_Maint_ToolKit-v0.3.8-ed4402b.tgz
- Provenance manifest: release_provenance.json
- Detached signature: none

## Operator follow-up

- Recommended post-upgrade verification:
  - `linux-maint verify-install`
  - `linux-maint status`
  - `linux-maint doctor`
