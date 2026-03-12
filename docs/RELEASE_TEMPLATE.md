# Release Notes Template

Use this template for tagged releases so operators can understand impact quickly.

## Header

- Version:
- Date (UTC):
- Git tag:
- Commit:

[Release history](https://github.com/ShenhavHezi/Linux_Maint_ToolKit/blob/main/docs/release_notes/README.md) · [Upgrade guide](https://github.com/ShenhavHezi/Linux_Maint_ToolKit/blob/main/docs/UPGRADE.md)

## Summary

Write 2 to 4 short lines that answer:

- What changed for operators?
- What changed for packagers or maintainers?
- Is this mainly features, fixes, or release hardening?

## Highlights

- 

## Operator impact

- 

## Upgrade and compatibility notes

- Breaking changes:
  - None
- Upgrade notes:
  - 
- Compatibility notes:
  - 

## Fixes

- 

## Docs and UX

- 

## Validation

- `bash tools/release_check.sh`
- `bash tools/release_audit.sh`
- `bash tests/smoke.sh`
- additional focused checks:
  - 

## Release assets

- Tarball:
- SHA256SUMS:
- Provenance manifest:
- Detached signature:

## Operator follow-up

- Recommended post-upgrade verification:
  - `linux-maint verify-install`
  - `linux-maint status`
  - `linux-maint doctor`
