# Installation

Use this page when you are deciding how to deploy `linux-maint` on a real system.

For air-gapped delivery, use [DARK_SITE.md](DARK_SITE.md). For upgrade and rollback, use [UPGRADE.md](UPGRADE.md).

## Choose the path

### Repo mode

Best for:

- evaluation
- development
- CI
- running from a monitoring node without installing system-wide files

Typical flow:

```bash
git clone https://github.com/ShenhavHezi/Linux_Maint_ToolKit.git
cd Linux_Maint_ToolKit
./bin/linux-maint init --minimal
./bin/linux-maint check
./bin/linux-maint run
```

### Installed mode

Best for:

- persistent hosts
- systemd timer operation
- stable system-wide paths

Recommended install:

```bash
sudo ./install.sh --with-user --with-timer --with-logrotate
sudo linux-maint init --minimal
sudo linux-maint verify-install
```

### RPM mode

Best for:

- RHEL 9 style environments
- RPM-managed lifecycle
- packaged install/remove/upgrade workflows

Rocky Linux 9 is the CI-tested RHEL 9-compatible packaging lane.

## What the project targets

- primary target: **RHEL 9**
- also validated in CI on Debian 12, Ubuntu 24.04, and Rocky Linux 9

Minimum practical requirements:

- `bash` 4.2+
- standard core utilities
- `python3`
- `ssh` client for fleet mode
- root or `sudo` recommended for installed mode

Optional tooling improves coverage:

- `smartctl`
- `nvme`
- vendor RAID CLIs

## Recommended installed workflow

```bash
sudo ./install.sh --with-user --with-timer --with-logrotate
sudo linux-maint init --minimal
sudo linux-maint check
sudo linux-maint verify-install
sudo linux-maint run
sudo linux-maint status
```

What this gives you:

- installed `linux-maint` CLI
- wrapper and helper payload
- config skeleton under `/etc/linux_maint`
- log/state layout under `/var/log/health` and `/var/lib/linux_maint`
- optional timer and logrotate integration

## Packaging notes

- RPM packaging is supported and tested
- DEB packaging is not currently provided
- on Debian/Ubuntu, use repo mode or a verified release tarball

## Repo vs installed mode

### Repo mode

- safest for trying the toolkit without touching system-wide paths
- wrapper artifacts default to `.logs/`
- config can stay repo-local

### Installed mode

- best for long-lived scheduled operation
- uses `/etc/linux_maint`, `/var/log/health`, and `/var/lib/linux_maint`
- some checks need root access to inspect privileged state

If you are not sure, start in repo mode, then install once the output and workflow fit your environment.

## Verification after install

Do not stop at “installer finished.”

Run:

```bash
sudo linux-maint verify-install
sudo linux-maint check
sudo linux-maint run --plan
```

This catches path drift, missing payload members, and readiness problems earlier than waiting for the first scheduled run.

## Manual or custom-layout installs

If you need a custom prefix or a manual layout, use:

- `PREFIX=/custom ./install.sh ...`
- [reference.md](reference.md) for the installed file layout

## Config templates

Common template files:

- `linux-maint.conf.example`
- `servers.txt.example`
- `services.txt.example`
- `monitor_timeouts.conf.example`
- `monitor_runtime_warn.conf.example`

## When to leave this page

- Use [configuration.md](configuration.md) to decide what to configure first
- Use [UPGRADE.md](UPGRADE.md) for verified upgrade and rollback flow
- Use [DARK_SITE.md](DARK_SITE.md) for disconnected delivery
