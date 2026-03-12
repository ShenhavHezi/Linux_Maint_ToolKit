# Release Notes v0.3.7

- Version: 0.3.7
- Date (UTC): 2026-03-12
- Git tag: v0.3.7

[Release history](https://github.com/ShenhavHezi/Linux_Maint_ToolKit/blob/main/docs/release_notes/README.md) · [Upgrade guide](https://github.com/ShenhavHezi/Linux_Maint_ToolKit/blob/main/docs/UPGRADE.md)

## Highlights

- Added a stronger `linux-maint upgrade --check` assessment with release date, compatibility notes, artifact-presence checks, and clearer operator guidance before upgrade.
- Deepened baseline lifecycle visibility with richer `baseline status` summaries, attention items, and refresh guidance in both human and JSON output.
- Improved inventory-aware run planning so `run --plan` explains inventory metadata context and fails clearly when tag/role/env filters match zero hosts.
- Continued CLI polish by bringing `trend`, `runtimes`, and `history` human output into the same guidance/summary style as the other polished operator commands.

## Upgrade assessment improvements

- `linux-maint upgrade --check` now reports:
  - target release date when present in bundled release notes
  - compatibility notes from the target release notes
  - whether release notes, the upgrade guide, checksums, and signatures were present in the assessment
- `linux-maint upgrade --check --json` now includes:
  - `target_date_utc`
  - `checks`
  - `compatibility_notes`
  - `next_steps`
  - `result`

## Baseline lifecycle visibility

- `linux-maint baseline status` now reports:
  - fresh vs stale baseline counts
  - drift item counts
  - changed-host totals
  - attention items by baseline kind
  - clearer refresh/report next steps
- `linux-maint baseline status --json` now includes:
  - `summary`
  - `attention_items`
  - `next_steps`
  - `result`

## Inventory-aware planning

- `linux-maint run --plan --json` now reports:
  - inventory metadata path
  - whether `inventory_meta.csv` was present
  - inventory host count vs matched host count
  - discovered roles, environments, and tags
- `run` and `run --plan` now fail with `rc=2` when `--tag`, `--role`, or `--env` match zero hosts, and they show the requested filters plus the available metadata values.

## Reporting and operator UX polish

- `trend`, `runtimes`, and `history` now end with consistent `Guidance` and `Summary` blocks plus final status labels.
- `metrics` now points users at `report`/`status` when invoked without an explicit machine output format.
- `logs` now gives clearer missing/unreadable file hints without changing the raw successful log tail output.

## Compatibility notes

- No intended breaking CLI or JSON contract changes for existing fields; the upgrade and baseline JSON outputs only grew additional fields.
- RHEL 9 remains the primary platform target, with Rocky Linux 9 continuing as the compatible RPM CI lane.
- Operators upgrading from `v0.3.6` can keep using `linux-maint upgrade` and should run `linux-maint verify-install` after the upgrade finishes.
