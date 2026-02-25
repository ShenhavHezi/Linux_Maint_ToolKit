# Linux Maintenance Toolkit (linux-maint)

**`linux-maint` is a lightweight health and maintenance toolkit for Linux administrators.**
Run it locally or from a monitoring node over SSH to get structured logs and OK/WARN/CRIT summaries.
Target: RHEL 9. Offline/dark-site friendly.

## Table of Contents

- [Features](#features)
- [Quickstart](#quickstart)
- [Configuration](#configuration)
- [Modes](#modes)
- [Safety & contracts](#safety--contracts)
- [Outputs](#outputs)
- [Dark-site / offline](#dark-site--offline)
- [Documentation](#documentation)
- [Testing](#testing)

## Features

- Standardized summary contract (`monitor=... host=... status=... reason=...`) for automation.
- Runs locally or across fleets via SSH (`/etc/linux_maint/servers.txt`).
- Hardened wrapper with timeouts, SKIP gating for optional inputs, and machine-readable artifacts.
- Optional Prometheus textfile output and JSON outputs for tooling.
- Built-in self-checks and doctor workflow for setup validation.
- Human-friendly CLI with `status`, `summary`, `report`, and `diff` views.
- Optional interactive TUI menu (`linux-maint menu`) via gum/dialog/whiptail.
- Offline/dark-site friendly (no runtime network dependency).

## Quickstart

RHEL 9 (repo mode):

```bash
git clone https://github.com/ShenhavHezi/Linux_Maint_ToolKit.git
cd Linux_Maint_ToolKit
sudo ./run_full_health_monitor.sh
sudo ./bin/linux-maint status
```

Air-gapped quickstart (installed mode):

```bash
sudo ./install.sh --with-user --with-timer --with-logrotate
sudo linux-maint init --minimal
sudo linux-maint run
sudo linux-maint status
sudo linux-maint menu
```

For installed mode and timers, see `docs/installation.md`.

## Configuration

Config templates live in `etc/linux_maint/*.example` and are installed to `/etc/linux_maint/`.
Start here:
- `etc/linux_maint/README.md`
- `docs/configuration.md`

## Modes

- **Repo mode**: run from a git checkout (uses repo paths and `.logs/`).
- **Installed mode**: run from `/usr/local` with config in `/etc/linux_maint`.
  - Repo mode logs live under `.logs/` and are safe for non-root tests.
  - Installed mode logs live under `/var/log/health` and require root.

Install steps and timers: `docs/installation.md`.

## Safety & contracts

- Summary contract is stable and parse-safe: `monitor=... host=... status=... reason=...`
- Machine outputs stay clean; any progress UI goes to stderr.
- No runtime network dependencies; safe defaults for offline/dark-site use.

## Outputs

What you get by default:
- Machine-readable summary lines: `monitor=... host=... status=... reason=...`
- Wrapper logs: `/var/log/health/full_health_monitor_latest.log`
- Summary-only log: `/var/log/health/full_health_monitor_summary_latest.log`

For JSON payloads and full contracts, see `docs/reference.md`.

## Documentation

- Docs index: `docs/README.md`
- Quick reference: `docs/QUICK_REFERENCE.md`
- Full reference (monitors, outputs, contracts): `docs/reference.md`
- Installation: `docs/installation.md`
- Upgrade / rollback: `docs/UPGRADE.md`
- Troubleshooting: `docs/troubleshooting.md`

Pinned docs:
- Start here: `docs/README.md`
- Operator quick commands: `docs/QUICK_REFERENCE.md`

## Dark-site / offline

Designed for air-gapped environments: no runtime network dependency and conservative defaults.
See `docs/DARK_SITE.md` for offline install steps and bootstrap checklist.

## Testing

```bash
bash tests/smoke.sh
bash tests/summary_contract.sh  # when touching summary/json/monitor output
```

## Compatibility

Primary target: RHEL 9. CI covers Ubuntu 24.04 and Debian 12 (container).

Minimums:
- bash 4.2+
- coreutils, awk, sed, grep
- openssh client for SSH mode
- python3 for JSON tooling and contract tests

## Support

Support is best-effort. Please include:
- linux-maint version and mode (repo or installed)
- distro and shell version
- last log tail (`linux-maint logs 200`)
- summary output (`linux-maint status --verbose`)

For security issues, follow `SECURITY.md`.
