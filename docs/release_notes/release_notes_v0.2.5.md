# Release Notes v0.2.5

## Version
- Version: 0.2.5
- Date (UTC): 2026-02-24
- Git tag: v0.2.5

## Highlights
- Wrapper SKIP reasons now use stable tokens with `missing=` detail fields.
- `linux-maint diff --json` emits clean JSON-only output.
- Summary lint restored Python 3.6 compatibility for legacy CI.

## Breaking changes
- None

## New features
- None

## Fixes
- Wrapper SKIP reasons standardized to `config_missing` / `baseline_missing` with `missing=...`.
- Fixed `diff --json` output to remove non-JSON prefix lines.
- Fixed summary lint tooling for Python 3.6 (compat matrix).
- Fixed fixture naming in compat tests.

## Docs
- None

## Compatibility / upgrade notes
- If automation matched `reason=missing:/path`, update to `reason=config_missing` or `reason=baseline_missing` and read `missing=...` for detail.

## Checksums (if releasing a tarball)
- SHA256SUMS: 6fb33735e361af6b1e826902954b059f56416652fd3268f25548ea668d06fb9e  Linux_Maint_ToolKit-v0.2.5-af45c85.tgz
