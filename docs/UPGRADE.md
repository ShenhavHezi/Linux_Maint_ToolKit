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
- Run `sudo linux-maint status` after the next scheduled run to confirm expected SKIPs only.

## Upgrade (from release tarball)

If you are using a release tarball:

```bash
tar -xzf linux-maint-<version>.tar.gz
cd linux-maint-<version>
sudo ./install.sh --with-user --with-timer --with-logrotate
```

## Rollback (safe)

Rollback by reinstalling the previous version you trust.

From git:

```bash
git checkout v0.x.y
sudo ./install.sh --with-user --with-timer --with-logrotate
```

From a tarball:

```bash
tar -xzf linux-maint-<previous>.tar.gz
cd linux-maint-<previous>
sudo ./install.sh --with-user --with-timer --with-logrotate
```

Verify:

```bash
sudo linux-maint version
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
