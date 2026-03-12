# Release Notes v0.3.5

- Version: 0.3.5
- Date (UTC): 2026-03-12
- Git tag: v0.3.5

[Release history](https://github.com/ShenhavHezi/Linux_Maint_ToolKit/blob/main/docs/release_notes/README.md) · [Upgrade guide](https://github.com/ShenhavHezi/Linux_Maint_ToolKit/blob/main/docs/UPGRADE.md)

## Highlights
- Hardened the operational core again: wrapper/resume behavior, reporting input safety, advanced command validation, and installed-vs-repo path correctness.
- Split more of `bin/linux-maint` into dedicated support libraries so the CLI entrypoint is easier to maintain and release safely.
- Tightened install, RPM, and upgrade behavior around custom layouts, support-lib parity, and best-effort systemd handling.
- Cleaned up the public repo/docs surface so release history, maintainer guidance, and source-directory navigation are more deliberate.

## Runtime and reporting hardening
- Hardened `status`, `report`, `metrics`, `summary`, `trend`, `runtimes`, and `export` around:
  - separate `SUMMARY_DIR` handling
  - unreadable or malformed `last_status_full`
  - unreadable summary and wrapper log inputs
  - historical summary warning visibility for `--since` / `--last`
- Hardened wrapper/run behavior around:
  - invalid resume-state files
  - malformed lock metadata
  - corrupt run indexes
  - sidecar, Prometheus, status, and run-state write failures
  - summary-latest symlink correctness across override directories
- Fixed additional installed-mode read-only command drift so reporting and planning commands no longer require root unnecessarily.

## Advanced command hardening
- `serve` now:
  - validates port ranges before launch
  - reports bind failures cleanly
  - requires upstream contract-version fields, not just vaguely correct JSON shapes
- `plugin` handling is stricter:
  - invalid plugin names are rejected consistently
  - path-escape reads are blocked in verification and index attestation flows
  - corrupt registries and trust-policy problems fail more cleanly
- `policy lint`, `policy eval`, and `gate` now behave more predictably on unreadable or malformed policy files.
- Generated monitor scaffolds from `tools/new_monitor.sh` now work cleanly on both `/usr/local` and RPM-style `/usr` installs.

## CLI structure and maintainability
- Split more command surfaces into dedicated support libraries:
  - `linux_maint_config.sh`
  - `linux_maint_history.sh`
  - `linux_maint_ops.sh`
- The extracted ops layer now carries:
  - `tune`
  - `baseline`
  - `explain`
  - `pack-logs`
- Install, RPM, release verification, upgrade manifests, and installed-layout checks were updated so the new support libs are first-class payloads rather than repo-only assumptions.

## Install, packaging, and upgrade workflow
- Tightened release/install harness parity so support-lib splits fail fast if tarball, install, RPM, or `verify-install` payload lists drift.
- RPM builds now require a clean checkout, and Rocky/RHEL-oriented RPM packaging keeps the needed support libraries and config skeleton intact.
- `linux-maint upgrade` now propagates custom install-layout overrides for:
  - config
  - logs
  - state
  - systemd unit dir
  - logrotate file
- `install.sh --with-timer` now treats `systemctl` operations as bounded best-effort steps instead of blocking or failing installs in non-systemd contexts.

## Repo and docs polish
- Cleaned up root- and folder-level repo structure by moving maintainer and report artifacts into clearer homes, and by documenting internal source directories.
- Refined the docs hub, release-history pages, troubleshooting/reference material, and contributor entry surfaces to read more like a maintained product repo.
- Replaced conceptual menu artwork with captures/rendered output from the real menu flow and added a reusable menu demo asset pipeline.

## Compatibility notes
- No intended schema-breaking release.
- Primary platform target remains RHEL 9, with Rocky Linux 9 used as the compatible RPM CI lane.
- Operators upgrading from `v0.3.4` should continue using `linux-maint upgrade` for tarball-based installs; the upgrade path is stricter and safer in this release, especially for custom layouts.
