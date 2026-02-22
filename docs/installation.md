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

## Requirements (minimal)

- `bash` + standard core utilities (`awk`, `sed`, `grep`, `df`, `ps`, etc.)
- `ssh` client for distributed mode
- `sudo`/root recommended (many checks read privileged state and write to `/var/log` and `/etc/linux_maint`)

Optional (improves coverage): `smartctl` (smartmontools), `nvme` (nvme-cli), vendor RAID CLIs.

## Modes

- Repo mode (`./run_full_health_monitor.sh`, `./bin/linux-maint`): best for evaluation and local development.
- Installed mode (`linux-maint`, systemd timer/cron): best for production use and scheduled runs.

If you’re not sure, start with repo mode, then install once you like the output.

## Manual install (appendix)

If you prefer manual installation or need a custom layout, see `docs/reference.md` for full paths and contracts.
