# Upgrade and Rollback (installed mode)

This guide covers safe, short steps to upgrade or roll back an installed `linux-maint`.
Config and baselines live under `/etc/linux_maint` and are not overwritten by default.

## Upgrade (recommended)

From a repo checkout on the node:

```bash
git pull
sudo ./install.sh --with-user --with-timer --with-logrotate
```

Verify:

```bash
sudo linux-maint version
sudo linux-maint verify-install
sudo linux-maint check
```

Notes:
- Review `git diff` for config name changes or new optional files.
- The installer updates binaries and docs under `/usr/local` but keeps `/etc/linux_maint` intact.
- If the installer fails partway through an upgrade, it now restores the previous installed payload automatically.
- Run `sudo linux-maint status` after the next scheduled run to confirm expected SKIPs only.

## Upgrade (from release tarball)

If you are using a release tarball:

```bash
linux-maint upgrade ./Linux_Maint_ToolKit-v<version>-<sha>.tgz --check --sums ./SHA256SUMS
linux-maint upgrade ./Linux_Maint_ToolKit-v<version>-<sha>.tgz --check --json --sums ./SHA256SUMS
linux-maint upgrade ./Linux_Maint_ToolKit-v<version>-<sha>.tgz --plan --sums ./SHA256SUMS --rollback-tarball ./Linux_Maint_ToolKit-v<previous>-<sha>.tgz
linux-maint upgrade ./Linux_Maint_ToolKit-v<version>-<sha>.tgz --plan --json --sums ./SHA256SUMS
sudo linux-maint upgrade ./Linux_Maint_ToolKit-v<version>-<sha>.tgz --sums ./SHA256SUMS
sudo linux-maint upgrade ./Linux_Maint_ToolKit-v<version>-<sha>.tgz --sums ./SHA256SUMS --with-user --with-timer --with-logrotate
```

`linux-maint upgrade` verifies the tarball first, snapshots the current config dir, records rollback metadata under the active state dir, runs the extracted installer, and finishes with `verify-install`.

Use `--check` when you want to inspect the target release before changing the node. The check path:

- verifies the tarball and checksums
- compares installed vs target version
- reports the target release date when it is present in bundled release notes
- points at the target release notes and upgrade guide inside the tarball
- highlights the top release-note bullets
- surfaces compatibility notes when the release notes include them
- shows whether release notes, the upgrade guide, checksums, and signatures were present in the assessment
- warns when the target matches or predates the installed version

`linux-maint upgrade --check --json` emits a machine-readable assessment.
Schema:
- `docs/schemas/upgrade_check.json` — JSON schema for `linux-maint upgrade --check --json`.

Use `--plan` when you want a node-local impact preview before the live upgrade. The plan path:

- includes the same tarball/release assessment as `--check`
- previews config preservation and counts current config files and `conf.d` overrides
- shows current and planned systemd/logrotate effects for the active install paths
- scores rollback readiness from checksums, rollback artifact presence, and config readability
- keeps the node unchanged while pointing at the next safest operator step

`linux-maint upgrade --plan --json` emits a machine-readable plan.
Schema:
- `docs/schemas/upgrade_plan.json` — JSON schema for `linux-maint upgrade --plan --json`.

Upgrade artifacts:
- `/var/lib/linux_maint/upgrades/<run-id>/upgrade_manifest.json`
- `/var/lib/linux_maint/upgrades/<run-id>/config_snapshot.tgz`
- `/var/lib/linux_maint/upgrades/<run-id>/installed_payload_inventory.txt`
- `/var/lib/linux_maint/upgrades/<run-id>/rollback_instructions.txt`
- `/var/lib/linux_maint/upgrades/latest` (symlink to the newest manifest dir)

## Rollback (safe)

Rollback by reinstalling the previous version you trust.

From git:

```bash
git checkout v0.x.y
sudo ./install.sh --with-user --with-timer --with-logrotate
```

From a tarball:

```bash
sudo linux-maint upgrade ./Linux_Maint_ToolKit-v<previous>-<sha>.tgz --sums ./SHA256SUMS
```

If you keep a known-good rollback tarball on hand, record it during the forward upgrade:

```bash
sudo linux-maint upgrade ./Linux_Maint_ToolKit-v<version>-<sha>.tgz \
  --sums ./SHA256SUMS \
  --rollback-tarball ./Linux_Maint_ToolKit-v<previous>-<sha>.tgz
```

Verify:

```bash
sudo linux-maint version
sudo linux-maint verify-install
sudo linux-maint status
```

## If you need to pause scheduled runs

```bash
sudo systemctl disable --now linux-maint.timer
```

Re-enable later:

```bash
sudo systemctl enable --now linux-maint.timer
```

## RPM upgrades (RHEL/Rocky/Alma)

For RPM-managed installs, use the package manager for the binary upgrade and keep `linux-maint upgrade` for tarball-based nodes only.

```bash
sudo dnf upgrade -y ./linux-maint-<new-version>-*.noarch.rpm
sudo linux-maint verify-install
sudo linux-maint check
```

Notes:
- CI now exercises RPM `install`, `upgrade`, `reinstall`, and `remove` on Rocky 9.
- RPM upgrades preserve `/etc/linux_maint` content created by `linux-maint init`.
- RPM removal does not remove `/etc/linux_maint` by default.
