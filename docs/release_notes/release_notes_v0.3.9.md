# Release Notes v0.3.9

- Version: 0.3.9
- Date (UTC): 2026-04-28
- Git tag: v0.3.9
- Commit: c99f530

[Release history](https://github.com/ShenhavHezi/Linux_Maint_ToolKit/blob/main/docs/release_notes/README.md) · [Upgrade guide](https://github.com/ShenhavHezi/Linux_Maint_ToolKit/blob/main/docs/UPGRADE.md)

## Summary

This release focuses on safer fleet execution, audit portability, and more useful run artifacts.
Operators now get fail-closed host-group handling, portable audit-log attestations for WORM/object-lock transfer, and per-monitor privilege telemetry in run outputs and reports.
It also hardens CI and local test behavior across root/private-home environments, generated-state secret scanning, and release upgrade-note parsing.

## Highlights

- Hardened `linux-maint run --group` so missing group files fail closed instead of silently falling back to default hosts.
- Added `linux-maint audit-log --attest` with chain verification, audit-log SHA256, first/last chain anchors, event counts, overwrite protection, and read-only `--out` files.
- Added per-monitor privilege telemetry to run-state artifacts, wrapper summary JSON, and `linux-maint report`.
- Tightened smoke/CI behavior so failures are enforced instead of hidden behind best-effort execution.

## Operator impact

- `linux-maint run --group <name>` now exits `2` when the selected group file is missing or unreadable. This prevents accidental all-host/default-host runs caused by typos or incomplete config.
- `linux-maint audit-log --attest --out FILE` creates a portable JSON attestation you can store beside the audit log in append-only, WORM, or object-lock storage.
- `linux-maint report` now includes a privilege-policy summary when summary JSON contains privilege telemetry, including monitor count, policy results, violations, and policy file path.
- Summary JSON now includes an additive `privilege` object with local runner euid/user, per-monitor policy/result, and aggregate counts.

## Upgrade and compatibility notes

- Breaking changes:
  - None intended for valid configurations.
- Upgrade notes:
  - Review automation that used missing `--group` names as an implicit fallback; that behavior now fails closed with `rc=2`.
  - If you use audit logs for compliance evidence, start exporting attestations after critical operations with `linux-maint audit-log --attest --out <path>`.
  - If you enforce `monitor_privilege_policy.conf`, review `linux-maint report` after the next run to confirm local privilege telemetry is present.
- Compatibility notes:
  - Summary, report, and audit-log JSON changes are additive.
  - Existing summary `rows` and existing report/status contracts remain present.
  - The privilege telemetry records local wrapper execution context; remote host privilege telemetry is still planned separately.

## Fixes

- Fixed invalid Bash array length handling in the doctor package check path.
- Fixed upgrade release-note parsing so nested compatibility notes are surfaced for `upgrade --check` and `upgrade --plan`.
- Made baseline refresh plan tests date-stable instead of relying on fixed historical dates.
- Hardened unreadable-file and non-root tests under root/private-home worktrees by using readable temporary copies where needed.

## Docs and UX

- Updated quick reference and command reference for `audit-log --attest`, missing group failure behavior, and privilege telemetry.
- Added or expanded JSON schema coverage for audit attestation and summary/report privilege telemetry.
- Updated the roadmap to mark audit attestation and local privilege telemetry complete, with native WORM controls and remote privilege telemetry queued next.

## Validation

- `bash tools/release_check.sh`
- `bash tools/release_audit.sh`
- `bash tests/smoke.sh`
- additional focused checks:
  - `make quick-check`
  - `make docs-check`
  - `./tools/secret_scan.sh`
  - `bash tests/adminops/audit_log_attest_test.sh`
  - `bash tests/run/run_missing_group_test.sh`
  - `bash tests/run/run_privilege_telemetry_test.sh`
  - `bash tests/reporting/summary_json_schema_test.sh`

## Release assets

- Tarball: `Linux_Maint_ToolKit-v0.3.9-c99f530.tgz`
- SHA256SUMS: d1c4a4819ceea28a507c2b799f59e7fbfe386e6ffd3eeab40f2ca0af9c432f53  Linux_Maint_ToolKit-v0.3.9-c99f530.tgz
- Provenance manifest: release_provenance.json
- Detached signature: none

## Operator follow-up

- Recommended post-upgrade verification:
  - `linux-maint verify-install`
  - `linux-maint status`
  - `linux-maint report`
  - `linux-maint doctor`
