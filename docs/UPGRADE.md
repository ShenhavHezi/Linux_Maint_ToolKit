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
sudo linux-maint upgrade ./Linux_Maint_ToolKit-v<version>-<sha>.tgz --sums ./SHA256SUMS
sudo linux-maint upgrade ./Linux_Maint_ToolKit-v<version>-<sha>.tgz --sums ./SHA256SUMS --with-user --with-timer --with-logrotate
```

`linux-maint upgrade` verifies the tarball first, snapshots the current config dir, records rollback metadata under the active state dir, runs the extracted installer, and finishes with `verify-install`.

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
