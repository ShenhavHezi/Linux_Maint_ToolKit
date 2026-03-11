# Artifacts and Logs

This document describes the files produced by runs and where to look for them.

## Repo mode (local checkout)

- Logs and summaries are written under `./.logs/` by default.
- Example files:
  - `./.logs/full_health_monitor_<timestamp>.log`
  - `./.logs/full_health_monitor_summary_<timestamp>.log`
  - `./.logs/full_health_monitor_summary_<timestamp>.json`
  - `./.logs/last_status_full`

## Installed mode

Default locations under `/var/log/health`:

- Full log: `full_health_monitor_<timestamp>.log` and `full_health_monitor_latest.log`
- Summary log (only `monitor=` lines): `full_health_monitor_summary_<timestamp>.log` and `full_health_monitor_summary_latest.log`
- Summary JSON: `full_health_monitor_summary_<timestamp>.json` and `full_health_monitor_summary_latest.json`

## Summary contract line

Each monitor emits a single machine‑parseable summary line per target host:

```
monitor=<name> host=<target> status=<OK|WARN|CRIT|UNKNOWN|SKIP> node=<runner> reason=<token> [key=value ...]
```

Only these `monitor=` lines are written into the summary artifacts.

## CLI accessors

- `linux-maint status` — human view based on latest summary artifacts
- `linux-maint status --verbose` — raw `monitor=` lines
- `linux-maint status --json` — automation‑friendly payload
- `linux-maint export --json|--jsonl|--csv` — structured output for external systems
- `linux-maint pack-logs` — support bundle (includes `meta/bundle_manifest.txt`, `meta/redaction_report.txt`, `meta/support_handoff.txt`, and `meta/bundle_integrity.txt` when `sha256sum`+`stat` are available; supports `--gpg` encryption)

To decrypt a GPG-encrypted bundle:

```bash
gpg --output linux-maint-support.tar.gz --decrypt linux-maint-support-*.tar.gz.gpg
tar -tzf linux-maint-support.tar.gz
```

## Retention

If installed with `--with-logrotate`, log retention is handled via logrotate.
Without logrotate, logs can grow over time; consider an explicit retention policy.

## Prometheus textfile (optional)

If enabled, the wrapper can write:

- `/var/lib/node_exporter/textfile_collector/linux_maint.prom`

This file contains counters derived from `monitor=` summary lines.

## Release artifacts (integrity)

Release tarballs are accompanied by `SHA256SUMS` and `release_provenance.json`:

```bash
cd dist
sha256sum -c SHA256SUMS
# optional if linux-maint is already installed on the verification host
linux-maint verify-release Linux_Maint_ToolKit-*.tgz --sums SHA256SUMS --manifest release_provenance.json
```

`release_provenance.json` records the tarball name, SHA-256, version, tag, commit, branch, build time, and optional detached signature filename.

`linux-maint verify-release` validates the checksum, optional provenance manifest, `BUILD_INFO` / `VERSION` metadata, the required install payload members (`install.sh`, CLI/lib payload, helper tools, plugin index), and the matching release notes file for tagged release tarballs.

GitHub CI also emits artifact attestations for the built release tarball and Rocky RPM artifact on `push` runs.

## Upgrade manifests

`linux-maint upgrade` writes rollback metadata under the active state dir:

- `<state_dir>/upgrades/<run-id>/upgrade_manifest.json`
- `<state_dir>/upgrades/<run-id>/config_snapshot.tgz`
- `<state_dir>/upgrades/<run-id>/installed_payload_inventory.txt`
- `<state_dir>/upgrades/<run-id>/rollback_instructions.txt`
- `<state_dir>/upgrades/latest`

The manifest records the current version, target version, config snapshot path, payload inventory path, rollback artifact path (when supplied), and the final verify/install result.

## Packaging outputs

- Tarball builds: `dist/Linux_Maint_ToolKit-v<VERSION>-<sha>.tgz`, `dist/SHA256SUMS`, and `dist/release_provenance.json`
- RPM builds: `dist/rpm/` (created by `packaging/rpm/build_rpm.sh`)

To customize output paths, set `OUTDIR` when building:

```bash
OUTDIR=/tmp/out ./packaging/rpm/build_rpm.sh
```
