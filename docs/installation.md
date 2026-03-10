# Installation

This page covers recommended and manual installation options.
For a minimal run from the repo, see `README.md`.

## Recommended install

```bash
sudo ./install.sh --with-user --with-timer --with-logrotate
```

Manual install is also supported (see the appendix in this file).

## Supported environments (high level)

- Linux distributions: designed for common enterprise distros (RHEL-like, Debian/Ubuntu, SUSE-like). Some monitors auto-detect available tooling.
- Execution: local host checks and/or distributed checks over SSH from a monitoring node.
- Schedulers: cron or systemd timer (installer can set these up).

Current CI validation includes:
- installed lifecycle smoke on Ubuntu 24.04, Debian 12, and Rocky Linux 9
- RPM build/install smoke on Rocky Linux 9 as the RHEL 9-compatible packaging target

## Packaging note

RPM packages are supported and tested. DEB packaging is not currently provided.
For Debian/Ubuntu, use repo mode or the release tarball from `tools/make_tarball.sh`.
For RHEL 9 environments, Rocky Linux 9 is the CI-tested compatible target for install and RPM validation.

## Requirements (minimal)

- `bash` + standard core utilities (`awk`, `sed`, `grep`, `df`, `ps`, etc.)
- `ssh` client for distributed mode
- `sudo`/root recommended (many checks read privileged state and write to `/var/log` and `/etc/linux_maint`)

Optional (improves coverage): `smartctl` (smartmontools), `nvme` (nvme-cli), vendor RAID CLIs.

## Modes

- Repo mode (`./run_full_health_monitor.sh`, `./bin/linux-maint`): best for evaluation and local development.
- Installed mode (`linux-maint`, systemd timer/cron): best for production use and scheduled runs.

Repo mode writes wrapper artifacts under `.logs/`. If `/etc/linux_maint` is not writable, the wrapper falls back to a repo-local config directory (or `LM_CFG_DIR_FALLBACK`) and points monitors at that config root automatically.

If you’re not sure, start with repo mode, then install once you like the output.

## Manual install (appendix)

If you prefer manual installation or need a custom layout, see `docs/reference.md` for full paths and contracts.

## Config templates (quick note)

Example configs live under `etc/linux_maint/*.example`. Common ones:
- `linux-maint.conf.example`
- `servers.txt.example` / `services.txt.example`
- `monitor_timeouts.conf.example` (per-monitor timeouts)
- `monitor_runtime_warn.conf.example` (per-monitor runtime warn thresholds)
