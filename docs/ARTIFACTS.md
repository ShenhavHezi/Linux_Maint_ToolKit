# Artifacts and Logs

Use this page when you need to know what `linux-maint` writes, where it writes it, and what to send during escalation.

For incident handling, start with [troubleshooting.md](troubleshooting.md). For release and upgrade flow, pair this with [UPGRADE.md](UPGRADE.md).

## The important artifact groups

`linux-maint` mainly produces five kinds of artifacts:

- run logs
- summary logs and summary JSON
- state and history files
- support bundles
- release and packaging outputs

## Runtime artifacts

### Repo mode

Default output root:

- `./.logs/`

Typical files:

- `./.logs/full_health_monitor_<timestamp>.log`
- `./.logs/full_health_monitor_summary_<timestamp>.log`
- `./.logs/full_health_monitor_summary_<timestamp>.json`
- `./.logs/last_status_full`

### Installed mode

Default output root:

- `/var/log/health`

Typical files:

- `full_health_monitor_<timestamp>.log`
- `full_health_monitor_latest.log`
- `full_health_monitor_summary_<timestamp>.log`
- `full_health_monitor_summary_latest.log`
- `full_health_monitor_summary_<timestamp>.json`
- `full_health_monitor_summary_latest.json`
- `last_status_full`

### State and history

Default state root:

- `/var/lib/linux_maint`

Typical files:

- `run_index.jsonl`
- `last_summary_monitor_lines.log`
- audit log and summary-diff state
- upgrade manifests under `upgrades/`

## What is inside a summary artifact

Each monitor emits one machine-oriented summary line per target host:

```text
monitor=<name> host=<target> status=<OK|WARN|CRIT|UNKNOWN|SKIP> node=<runner> reason=<token> [key=value ...]
```

The wrapper collects those lines into:

- summary log files for humans and quick parsing
- summary JSON for CLI commands and automation

Most read-oriented commands work from these artifacts rather than recollecting data:

- `linux-maint status`
- `linux-maint report`
- `linux-maint trend`
- `linux-maint history`
- `linux-maint metrics`
- `linux-maint export`

## Useful readers

Use these commands instead of opening files directly unless you are debugging the raw artifacts:

- `linux-maint status`
- `linux-maint status --verbose`
- `linux-maint status --json`
- `linux-maint export --json`
- `linux-maint export --jsonl`
- `linux-maint export --csv`
- `linux-maint logs`

## Support bundles

Create a support bundle with:

```bash
linux-maint pack-logs --out /tmp
```

The bundle is the main escalation artifact. It can include:

- logs
- summaries
- state metadata
- release metadata
- redaction and integrity notes

Important files inside the bundle:

- `meta/bundle_manifest.txt`
- `meta/redaction_report.txt`
- `meta/support_handoff.txt`
- `meta/bundle_integrity.txt` when supported by local tooling
- `meta/bundle_hashes.txt` when hashing is explicitly enabled

### What to send with a support bundle

Send these together:

1. the generated archive
2. `meta/support_handoff.txt`
3. the output of `linux-maint status --verbose`
4. the exact version from `linux-maint version`

Also include whether the system is running in repo mode or installed mode.

### Encrypted bundles

If you use GPG encryption:

```bash
gpg --output linux-maint-support.tar.gz --decrypt linux-maint-support-*.tar.gz.gpg
tar -tzf linux-maint-support.tar.gz
```

Share the intended recipient details out-of-band so the receiver can confirm the expected key path.

## Release artifacts

Tarball releases produce:

- `dist/Linux_Maint_ToolKit-v<VERSION>-<sha>.tgz`
- `dist/SHA256SUMS`
- `dist/release_provenance.json`

Verify them with:

```bash
cd dist
sha256sum -c SHA256SUMS
linux-maint verify-release Linux_Maint_ToolKit-*.tgz --sums SHA256SUMS --manifest release_provenance.json
```

`release_provenance.json` records release identity metadata such as version, tag, commit, branch, tarball name, checksum, and optional detached signature filename.

## Upgrade artifacts

`linux-maint upgrade` writes rollback and review material under the active state dir:

- `<state_dir>/upgrades/<run-id>/upgrade_manifest.json`
- `<state_dir>/upgrades/<run-id>/config_snapshot.tgz`
- `<state_dir>/upgrades/<run-id>/installed_payload_inventory.txt`
- `<state_dir>/upgrades/<run-id>/rollback_instructions.txt`
- `<state_dir>/upgrades/latest`

Keep the whole run directory together if an upgrade fails and you need to debug or roll back.

## Packaging outputs

Build outputs:

- tarballs under `dist/`
- RPM artifacts under `dist/rpm/`

Example:

```bash
OUTDIR=/tmp/out ./packaging/rpm/build_rpm.sh
```

## Retention

If installed with logrotate support, runtime log retention is handled automatically.

Without logrotate, artifact growth is your responsibility. The first places to watch are:

- `/var/log/health`
- `/var/lib/linux_maint`
- repo-local `.logs/`

## Optional Prometheus export

When enabled, the toolkit can write:

- `/var/lib/node_exporter/textfile_collector/linux_maint.prom`

This file is derived from summary artifacts and is intended for textfile collector ingestion, not human editing.
