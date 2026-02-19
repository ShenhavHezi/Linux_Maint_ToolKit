# Linux Maintenance Toolkit (linux-maint)

`linux-maint` is a lightweight health/maintenance toolkit for Linux administrators.
Run it locally or from a monitoring node over SSH, get structured logs + a simple OK/WARN/CRIT summary.

Note: this project was previously named `linux_Maint_Scripts` on GitHub. The CLI remains `linux-maint`.

## Table of Contents

- [Docs / references](#docs-references)
- [Repo map (where to look)](#repo-map-where-to-look)
- [What you get](#what-you-get)
- [What it does](#what-it-does)
- [Supported environments (high level)](#supported-environments-high-level)
- [Requirements (minimal)](#requirements-minimal)
- [Dark-site / offline (air-gapped) use](#dark-site-offline-air-gapped-use)
- [Quickstart](#quickstart)
  - [Local run (from the repo)](#local-run-from-the-repo)
  - [Distributed run (monitoring node)](#distributed-run-monitoring-node)
- [Common operator workflows](#common-operator-workflows)
- [Install (recommended)](#install-recommended)
- [Configuration (the 3 files you’ll touch first)](#configuration-the-3-files-youll-touch-first)
- [How to read results](#how-to-read-results)
  - [Example: status output (compact)](#example-status-output-compact)
  - [Artifacts produced (installed mode)](#artifacts-produced-installed-mode)
  - [Summary contract (for automation)](#summary-contract-for-automation)
- [Common knobs](#common-knobs)

## Docs / references
- Changelog: [`CHANGELOG.md`](CHANGELOG.md) — release notes and summaries.
- Security policy: [`SECURITY.md`](SECURITY.md) — vulnerability reporting guidance.
- License: [`LICENSE`](LICENSE)

- Docs index: [`docs/README.md`](docs/README.md) — start here for navigation.
- Quick reference: [`docs/QUICK_REFERENCE.md`](docs/QUICK_REFERENCE.md) — day‑to‑day commands.
- Full reference: [`docs/reference.md`](docs/reference.md) — configuration, monitors, outputs, and contracts.
- Reason tokens: [`docs/REASONS.md`](docs/REASONS.md) — canonical `reason=` vocabulary.
- Offline / dark‑site: [`docs/DARK_SITE.md`](docs/DARK_SITE.md) — air‑gapped deployment guide.
- Day‑2 ops: [`docs/DAY2.md`](docs/DAY2.md) — patching, baselines, trends, runtime tuning.
- Release checklist: [`docs/RELEASE_CHECKLIST.md`](docs/RELEASE_CHECKLIST.md) — publishing steps and gates.
- Release template: [`docs/RELEASE_TEMPLATE.md`](docs/RELEASE_TEMPLATE.md) — release notes template.
- Docs index (short): [`docs/INDEX.md`](docs/INDEX.md) — quick link list.


## Repo map (where to look)

- **Run it (wrapper)**: `run_full_health_monitor.sh`
- **CLI**: `bin/linux-maint` (installed as `linux-maint`)
- **Monitors**: `monitors/` (each emits `monitor=... status=...` summary lines)
- **Shared Bash library**: `lib/linux_maint.sh`
- **Config templates**: `etc/linux_maint/` (copy to `/etc/linux_maint/`)
- **Operator docs**: `docs/`
- **Tools (release/lint helpers)**: `tools/`
- **Tests**: `tests/`

## What you get

- **Standardized summary contract** per monitor (`monitor=... host=... status=... reason=...`) for automation.
- **Hardened wrapper**: if a monitor fails without emitting a summary line, the wrapper emits `status=UNKNOWN reason=early_exit`.
- **Timeout protection** per monitor (`MONITOR_TIMEOUT_SECS`) to avoid hanging runs.
- **Config/baseline gating with SKIP**: missing optional files produce `status=SKIP` with a reason.
- **Fleet counters** derived from summary lines (`SUMMARY_HOSTS ok=.. warn=.. crit=.. unknown=.. skipped=..`).
- Optional **Prometheus textfile** output for node_exporter.

## What it does

- Runs a set of modular checks (disk/inodes, CPU/memory/load, services, network reachability, NTP drift, patch/reboot hints,
  kernel events, cert expiry, NFS mounts, storage health best-effort, backups freshness, inventory export, and drift checks).
- Works **locally** or **across many hosts** via `/etc/linux_maint/servers.txt`.
- Produces machine-parseable summary lines (`monitor=... status=...`) and an aggregated run log.

## Supported environments (high level)

- **Linux distributions**: designed for common enterprise distros (RHEL-like, Debian/Ubuntu, SUSE-like). Some monitors auto-detect available tooling.
- **Execution**: local host checks and/or distributed checks over SSH from a monitoring node.
- **Schedulers**: cron or systemd timer (installer can set these up).

## Requirements (minimal)

- `bash` + standard core utilities (`awk`, `sed`, `grep`, `df`, `ps`, etc.)
- `ssh` client for distributed mode
- `sudo`/root recommended (many checks read privileged state and write to `/var/log` and `/etc/linux_maint`)

Optional (improves coverage): `smartctl` (smartmontools), `nvme` (nvme-cli), vendor RAID CLIs.

## Dark-site / offline (air-gapped) use

This project is designed to work in environments without direct Internet access.

Typical workflow:
1. On a connected machine, download a release tarball (or clone the repo).
2. Transfer it to the dark-site environment.
3. Install using `install.sh` and your internal package repos/mirrors.

Full offline install steps: [`docs/DARK_SITE.md`](docs/DARK_SITE.md).

Day-0 tip: use the bootstrap checklist in `docs/DARK_SITE.md` (minimum required files + normal expected `SKIP` statuses on first run).

Release/version tracking notes and deeper configuration reference: [`docs/reference.md`](docs/reference.md).

## Quickstart

### Local run (from the repo)

```bash
git clone https://github.com/ShenhavHezi/Linux_Maint_ToolKit.git
cd Linux_Maint_ToolKit
sudo ./run_full_health_monitor.sh
sudo ./bin/linux-maint status
```

### Distributed run (monitoring node)

Example using CLI flags (recommended):

```bash
sudo linux-maint run --group prod --parallel 10
# or
sudo linux-maint run --hosts server-a,server-b --exclude server-c
```

Planning safely (no execution):

```bash
sudo linux-maint run --group prod --dry-run
sudo linux-maint run --group prod --dry-run --shuffle --limit 10
sudo linux-maint run --group prod --debug --dry-run
```

```bash
sudo install -d -m 0755 /etc/linux_maint
printf '%s\n' server-a server-b server-c | sudo tee /etc/linux_maint/servers.txt
sudo /usr/local/sbin/run_full_health_monitor.sh
```

## Which mode should I use?

- **Repo mode** (`./run_full_health_monitor.sh`, `./bin/linux-maint`): best for evaluation and local development.
- **Installed mode** (`linux-maint`, systemd timer/cron): best for production use and scheduled runs.

If you’re not sure, start with repo mode, then install once you like the output.

## Common operator workflows

### Run and review (single host)

```bash
sudo ./run_full_health_monitor.sh
sudo ./bin/linux-maint status
```

### Run a fleet (SSH / monitoring node)

```bash
sudo linux-maint run --group prod --parallel 10
sudo linux-maint status
```

### See what changed since last run

```bash
sudo linux-maint diff
```

### Troubleshoot / gather support bundle (offline-friendly)

```bash
sudo linux-maint doctor
sudo linux-maint doctor --json
linux-maint self-check
sudo linux-maint deps
sudo linux-maint export --json
sudo linux-maint export --csv
sudo linux-maint pack-logs --out /tmp
```

Notes:
- Full CLI reference: [`docs/reference.md`](docs/reference.md)
- Reason tokens: [`docs/REASONS.md`](docs/REASONS.md)

## Install (recommended)

```bash
sudo ./install.sh --with-user --with-timer --with-logrotate
```

Manual install is also supported (see Appendix).

## Configuration (the 3 files you’ll touch first)

Templates are in `etc/linux_maint/*.example`; installed configs live in `/etc/linux_maint/`.

See: [`etc/linux_maint/README.md`](etc/linux_maint/README.md) for a quick overview of the config templates.

- `servers.txt` — target hosts for SSH mode
- `services.txt` — services to verify
- `network_targets.txt` — optional reachability checks (if missing/empty, wrapper emits `SKIP` for `network_monitor`)

Dark-site tip:
- In air-gapped environments, keep `network_targets.txt` absent until you have internal targets to test; `network_monitor` will be auto-skipped with a clear `reason=missing:...` summary line.

## How to read results

Reason tokens reference: [`docs/REASONS.md`](docs/REASONS.md).

### Example: status output (compact)

```text
$ sudo linux-maint status
...
=== Summary (compact) ===
totals: CRIT=1 WARN=2 UNKNOWN=0 SKIP=1 OK=14

problems:
CRIT ntp_drift_monitor host=server-a reason=ntp_drift_high
WARN patch_monitor host=server-a reason=security_updates_pending
SKIP backup_check host=server-a reason=missing_targets_file
```

Tips:
- `sudo linux-maint status --verbose` for raw summary lines
- `sudo linux-maint diff` to show changes since the last run
- `sudo linux-maint status --problems 100` to list more problems (max 100)
- `sudo linux-maint status --reasons 5` to show the top reason tokens with counts
- `sudo linux-maint status --host web --monitor service --only WARN` to narrow noisy output quickly
- `sudo linux-maint status --since 2h` to focus on summary artifacts generated in the last time window
- `sudo linux-maint status --host '^web-[0-9]+$' --match-mode regex` for exact regex targeting
- `sudo linux-maint status --json` for automation-friendly output (see `docs/reference.md`)

- **Exit codes** (wrapper): `0 OK`, `1 WARN`, `2 CRIT`, `3 UNKNOWN`
- Logs:
  - Aggregated: `/var/log/health/` (installed mode)
  - Per-monitor: `/var/log/` (or overridden via `LM_LOGFILE`)

### Artifacts produced (installed mode)

The wrapper writes both a full log and summary artifacts you can parse/ship to monitoring:

- Full run log: `/var/log/health/full_health_monitor_<timestamp>.log` + `full_health_monitor_latest.log`
- Summary (only `monitor=` lines): `/var/log/health/full_health_monitor_summary_<timestamp>.log` + `full_health_monitor_summary_latest.log`
- Summary JSON: `..._summary_<timestamp>.json` + `..._summary_latest.json`
- Prometheus textfile (optional): `/var/lib/node_exporter/textfile_collector/linux_maint.prom`

See the full contract and artifact details in [`docs/reference.md`](docs/reference.md#output-contract-machine-parseable-summary-lines).
- The wrapper also emits fleet-accurate counters derived from `monitor=` lines: `SUMMARY_HOSTS ok=.. warn=.. crit=.. unknown=.. skipped=..`.

Log retention: use `./install.sh --with-logrotate` or create a logrotate entry for `/var/log/health` to prevent unbounded growth.

### Summary contract (for automation)

Each monitor emits lines like:

```text
monitor=<name> host=<target> status=<OK|WARN|CRIT|UNKNOWN|SKIP> node=<runner> key=value...
```

Notes:
- For non-`OK` statuses, monitors typically include a `reason=<token>` key (e.g. `ssh_unreachable`, `baseline_missing`, `collect_failed`).
- Full contract details and artifact locations are documented in [`docs/reference.md`](docs/reference.md#output-contract-machine-parseable-summary-lines).
- `SKIP` means the monitor intentionally did not evaluate (e.g., missing optional config/baseline).
- See [`docs/REASONS.md`](docs/REASONS.md) for standardized `reason=` tokens.

## First run expectations (normal SKIPs)

On a fresh install, it’s normal to see `status=SKIP` for monitors that need optional inputs:

- `network_monitor` — missing `/etc/linux_maint/network_targets.txt`
- `cert_monitor` — missing `/etc/linux_maint/certs.txt`
- `ports_baseline_monitor` — missing `/etc/linux_maint/ports_baseline.txt`
- `config_drift_monitor` — missing `/etc/linux_maint/config_paths.txt`
- `user_monitor` — missing `/etc/linux_maint/baseline_users.txt` or `baseline_sudoers.txt`
- `backup_check` — missing `/etc/linux_maint/backup_targets.csv`

These SKIPs are expected until you populate the files. Use `linux-maint doctor` for specific fix suggestions.

## Common fixes (quick reference)

- `ssh_unreachable`: confirm host is reachable, SSH keys are valid, and firewall allows port 22.
- `missing_dependency`: install the missing tool listed in the summary (e.g., `curl`, `smartctl`).
- `missing_optional_cmd`: install the optional tool (e.g., `chronyc`/`ntpq`) or accept the SKIP.
- `config_missing`: run `sudo linux-maint init` and populate the missing file.
- `baseline_missing`: allow baseline auto-init or create baseline files under `/etc/linux_maint/baselines/`.
- `service_failed`: check `systemctl status <unit>` and recent journal logs.
- `security_updates_pending`: run your distro update command and re-check.
- `log_spike_warn`: review recent logs for the monitor's target and tune thresholds/ignore lists if expected.
- `summary_write_failed` / `summary_checksum_failed`: confirm `/var/log/health` is writable and has free space.

### Automation-friendly JSON outputs

- `linux-maint status --json` — latest status, totals, problems, and runtime warnings.
- `linux-maint report [--json] [--compact] [--table]` — concise report combining status, trends, and slow monitors (table output supported).
- `linux-maint check` — run config_validate + preflight and show expected SKIPs.
- `linux-maint history --last N [--json] [--table]` — recent run list from run index (fast, no log scan).
- `linux-maint summary [--no-color]` — one-line latest summary (cron/dashboards).
- `linux-maint status --summary` — one-line latest summary (alias of `summary`).
- `linux-maint status --table` — table-formatted problems list.
- `linux-maint status --compact` — hide install metadata; show last run + summary only.
- `linux-maint doctor --compact` — hide file/systemd details; show key checks only.
- `linux-maint self-check --compact` — show config checks only.
- `linux-maint doctor --json` — config/dep/writable checks with fix suggestions.
- `linux-maint trend --json` — aggregated reason/severity trends.
- `linux-maint runtimes --json` — per-monitor runtime history.
- `linux-maint export --json` — unified payload for external ingestion.
- `linux-maint export --csv` — summary rows for spreadsheets/BI tools.

## Common knobs

### Optional email notification (single summary per run)

Create `/etc/linux_maint/notify.conf`:

```bash
LM_NOTIFY=1
LM_NOTIFY_TO="ops@company.com"
LM_NOTIFY_ONLY_ON_CHANGE=1
```

Details in [`docs/reference.md`](docs/reference.md).

- `MONITOR_TIMEOUT_SECS` (default `600`)
- `LM_EMAIL_ENABLED=false` by default
- `LM_NOTIFY` (wrapper-level per-run email summary; default `0` / off)
- `LM_SSH_OPTS` (e.g. `-o BatchMode=yes -o ConnectTimeout=3`)
- `LM_LOCAL_ONLY=true` (force local-only; used in CI)
- `LM_DARK_SITE=true` (optional profile: defaults `LM_LOCAL_ONLY=true`, `LM_NOTIFY_ONLY_ON_CHANGE=1`, `MONITOR_TIMEOUT_SECS=300` unless explicitly overridden)
