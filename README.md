# Linux Maintenance Toolkit (linux-maint)

`linux-maint` is a lightweight health/maintenance toolkit for Linux administrators.
Run it locally or from a monitoring node over SSH, get structured logs + a simple OK/WARN/CRIT summary.

## What it does

- Runs a set of modular checks (disk/inodes, CPU/memory/load, services, network reachability, NTP drift, patch/reboot hints,
  kernel events, cert expiry, NFS mounts, storage health best-effort, backups freshness, inventory export, and drift checks).
- Works **locally** or **across many hosts** via `/etc/linux_maint/servers.txt`.
- Produces machine-parseable summary lines (`monitor=... status=...`) and an aggregated run log.

## Quickstart

### Local run (from the repo)

```bash
git clone https://github.com/ShenhavHezi/linux_Maint_Scripts.git
cd linux_Maint_Scripts
sudo ./run_full_health_monitor.sh
sudo ./bin/linux-maint status
```

### Distributed run (monitoring node)

```bash
sudo install -d -m 0755 /etc/linux_maint
printf '%s
' server-a server-b server-c | sudo tee /etc/linux_maint/servers.txt
sudo /usr/local/sbin/run_full_health_monitor.sh
```

## Install (recommended)

```bash
sudo ./install.sh --with-user --with-timer --with-logrotate
```

Manual install is also supported (see Appendix).

## Configuration (the 3 files you’ll touch first)

Templates are in `etc/linux_maint/*.example`; installed configs live in `/etc/linux_maint/`.

- `servers.txt` — target hosts for SSH mode
- `services.txt` — services to verify
- `network_targets.csv` — optional reachability checks

## How to read results

- **Exit codes** (wrapper): `0 OK`, `1 WARN`, `2 CRIT`, `3 UNKNOWN`
- Logs:
  - Aggregated: `/var/log/health/` (installed mode)
  - Per-monitor: `/var/log/` (or overridden via `LM_LOGFILE`)

### Summary contract (for automation)

Each monitor emits lines like:

```text
monitor=<name> host=<target> status=<OK|WARN|CRIT|UNKNOWN|SKIP> node=<runner> key=value...
```

## Common knobs

- `MONITOR_TIMEOUT_SECS` (default `600`)
- `LM_EMAIL_ENABLED=false` by default
- `LM_SSH_OPTS` (e.g. `-o BatchMode=yes -o ConnectTimeout=3`)
- `LM_LOCAL_ONLY=true` (force local-only; used in CI)

## Table of Contents

- [What it does](#what-it-does)
- [Quickstart](#quickstart)
  - [Local run (from the repo)](#local-run-from-the-repo)
  - [Distributed run (monitoring node)](#distributed-run-monitoring-node)
- [Install (recommended)](#install-recommended)
- [Configuration (the 3 files you’ll touch first)](#configuration-the-3-files-youll-touch-first)
- [How to read results](#how-to-read-results)
  - [Summary contract (for automation)](#summary-contract-for-automation)
- [Common knobs](#common-knobs)
- [Full reference](docs/reference.md)


## Full reference

See [`docs/reference.md`](docs/reference.md) for monitors reference, tuning per monitor, configuration file details, offline/air-gapped notes, CI, uninstall, upgrading, etc.
