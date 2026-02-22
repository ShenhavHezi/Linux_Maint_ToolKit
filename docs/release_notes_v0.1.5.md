# Release Notes Template

## Version
- Version: 0.1.5
- Date (UTC): 2026-02-22
- Git tag: v0.1.5

## Highlights
- Progress controls for runs, baseline updates, and support bundles.
- Stronger redaction controls for support bundles with explicit metadata.
- New JSON contracts/schemas and richer runtimes JSON output.

## Breaking changes
- None

## New features
- `--progress|--no-progress` flags for `run`, `baseline`, and `pack-logs`.
- `pack-logs --redact|--no-redact` to override `LM_REDACT_LOGS` per bundle.
- Bundle metadata now includes `meta/bundle_meta.txt` with redaction status.
- `linux-maint help <command>` for quick per-command usage.
- `runtimes --json` now includes `unit` and `source_file`.
- Added release automation: `tools/release.sh` and `make release`.
- Expanded secret scan patterns for common tokens (GitHub/Slack/Google/Stripe/AWS).

## Fixes
- Locked color precedence: `NO_COLOR` overrides `LM_FORCE_COLOR`.
- Progress output is kept on stderr and never contaminates JSON outputs.

## Docs
- Updated reference and quick-reference docs for new flags and JSON contracts.
- Added output conventions and JSON contract sections.

## Compatibility / upgrade notes
- JSON outputs add new top-level contract versions for `report` and `config`; additive only.
- Runtimes JSON rows now include `unit` and `source_file`.

## Checksums (if releasing a tarball)
- SHA256SUMS:
