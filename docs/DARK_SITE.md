# Dark-site / air-gapped deployment guide

This project supports offline installation by generating a self-contained tarball.
It was previously named `linux_Maint_Scripts`; the CLI remains `linux-maint`.

## 1) Build the tarball (connected workstation)

```bash
git clone https://github.com/ShenhavHezi/Linux_Maint_ToolKit.git
cd Linux_Maint_ToolKit

./tools/make_tarball.sh
# output: dist/Linux_Maint_ToolKit-<version>-<sha>.tgz

# optional detached signature (if GPG key is available)
SIGN_KEY="ops-release@example.com" ./tools/make_tarball.sh
```

Integrity file (recommended):

```bash
( cd dist && sha256sum Linux_Maint_ToolKit-*.tgz > SHA256SUMS )
```

## 2) Transfer into the offline environment (staging / hop)

Move the tarball using your approved process. In many environments this is a multi-step “hop”, for example:

- connected workstation → staging machine / scanning station → removable media → offline network → target servers

Copy:
- `dist/Linux_Maint_ToolKit-*.tgz`
- `dist/SHA256SUMS`

On the offline side verify from the directory containing the files:

```bash
sha256sum -c SHA256SUMS

# or use bundled helper
linux-maint verify-release Linux_Maint_ToolKit-*.tgz --sums SHA256SUMS
```

## 3) Install on the offline server(s)

On each target server (after you copy the tarball over, it will usually be in your working directory — not under `dist/`):

```bash
tar -xzf Linux_Maint_ToolKit-*.tgz
cd Linux_Maint_ToolKit-*

sudo ./install.sh --with-logrotate
# optional:
# sudo ./install.sh --with-user --with-timer --with-logrotate

# verify:
linux-maint verify-install || true
linux-maint version || true
sudo linux-maint status || true
```


## 4) Minimal startup (after installation)

1) Review the generated configs under `/etc/linux_maint/` (the installer creates defaults).
   - If you want just the minimum startup files, run: `sudo linux-maint init --minimal`
2) Run once manually to validate everything works:

```bash
sudo linux-maint run
sudo linux-maint status
```

3) If you installed the timer (`--with-timer`), confirm it is active:

```bash
systemctl status linux-maint.timer --no-pager || true
systemctl list-timers | grep -i linux-maint || true
```

### Day-0 bootstrap checklist (minimum files + expected first-run SKIPs)

For the first successful run in dark-site mode, this minimum set is enough:

- required now:
  - `/etc/linux_maint/servers.txt`
  - `/etc/linux_maint/excluded.txt` (can be empty)
  - `/etc/linux_maint/services.txt`
- optional for later (safe to leave missing on day-0):
  - `/etc/linux_maint/network_targets.txt`
  - `/etc/linux_maint/certs.txt`
  - `/etc/linux_maint/ports_baseline.txt`
  - `/etc/linux_maint/config_paths.txt`
  - `/etc/linux_maint/baseline_users.txt`
  - `/etc/linux_maint/baseline_sudoers.txt`

Expected day-0 status behavior:

- `network_monitor` may show `status=SKIP reason=missing:/etc/linux_maint/network_targets.txt`
- `cert_monitor` may show `status=SKIP reason=missing:/etc/linux_maint/certs.txt`
- baseline-gated monitors may show `SKIP` until their baseline files are created

These SKIPs are normal on first run and indicate missing optional inputs, not wrapper failure.


## First 30 minutes runbook (offline day-0)

Use this when you are onboarding a new offline host and want a predictable first success path.

1) **Verify install + paths**

```bash
linux-maint verify-install || true
linux-maint version || true
```

2) **Create minimum config only**

```bash
sudo linux-maint init --minimal
```

3) **Fill minimum input files**
- `/etc/linux_maint/servers.txt` (at least one host or `localhost`)
- `/etc/linux_maint/services.txt` (a few critical services)
- `/etc/linux_maint/excluded.txt` (optional, may stay empty)

4) **Run first check and inspect status**

```bash
sudo linux-maint run
sudo linux-maint status --reasons 5
```

5) **Interpret normal first-run SKIPs**
- `reason=missing:/etc/linux_maint/network_targets.txt` → expected until network targets are defined.
- `reason=missing:/etc/linux_maint/certs.txt` → expected until certificate paths are defined.
- Baseline-related SKIPs → expected until baseline files are created/populated.

6) **Collect troubleshooting bundle (if needed)**

```bash
sudo linux-maint pack-logs
```

## 5) Run manually (quick test)

```bash
sudo linux-maint run
sudo linux-maint logs 200
```

## Notes

- Installed mode is intended to run as root (or via sudo) because it uses `/var/log` and `/var/lock`.
- For per-monitor configuration, see files under `/etc/linux_maint/` (created by the installer).
- Optional profile: set `LM_DARK_SITE=true` in `/etc/linux_maint/linux-maint.conf` for conservative defaults (`LM_LOCAL_ONLY=true`, `LM_NOTIFY_ONLY_ON_CHANGE=1`, wrapper `MONITOR_TIMEOUT_SECS=300`) while still allowing explicit overrides.
- Shortcut: `sudo linux-maint tune dark-site` writes the recommended dark-site defaults into `linux-maint.conf` without overwriting existing values.
- For dark-site simplicity, you can leave `/etc/linux_maint/network_targets.txt` absent at first; the wrapper will mark `network_monitor` as `SKIP` (reason includes the missing file path) instead of forcing network checks.

### Dark-site defaults for new monitors

If you use the **daily** timer created by `install.sh` (`02:15`), increase the last-run age threshold to avoid false alerts:

```bash
# /etc/linux_maint/linux-maint.conf
LM_LAST_RUN_MAX_AGE_MIN=1800   # 30 hours (daily schedule + cushion)
LM_LAST_RUN_LOG_DIR="/var/log/health"
```

If you have intentionally read-only mounts (e.g., ISO media), add them to the exclude regex:

```bash
# /etc/linux_maint/linux-maint.conf
LM_FS_RO_EXCLUDE_RE='^(proc|sysfs|devtmpfs|tmpfs|devpts|cgroup2?|cgroup|debugfs|tracefs|mqueue|hugetlbfs|pstore|squashfs|overlay|rpc_pipefs|autofs|fuse\..*|binfmt_misc|iso9660)$'
LM_FS_RO_EXCLUDE_MOUNTS_RE='^/(boot|boot/efi|usr|etc)$'
```
- Full reference: [`reference.md`](reference.md)

### Read-only mounts baseline (allowlist)

Identify intentionally read-only mounts:

```bash
findmnt -rno TARGET,FSTYPE,OPTIONS | awk '$3 ~ /(^|,)ro(,|$)/ {print}'
```

If any are expected (ISO media, recovery images, container mounts), add the relevant filesystem types to `LM_FS_RO_EXCLUDE_RE` in `linux-maint.conf`.


## Verify integrity (recommended)

When transferring tarballs/packages into an air-gapped environment, verify integrity:

```bash
sha256sum Linux_Maint_ToolKit-*.tgz > SHA256SUMS
# transfer both files
sha256sum -c SHA256SUMS

# or use bundled helper
linux-maint verify-release Linux_Maint_ToolKit-*.tgz --sums SHA256SUMS
```

If you use an internal artifact repository, store the checksum alongside the artifact.

## What to transfer

At minimum transfer:
- the release tarball (or git checkout) of this repository
- any required OS packages / dependencies (via your internal mirrors)
- your environment-specific config files under `/etc/linux_maint/`

Tip: `linux-maint make-tarball` can help create a self-contained bundle for offline use.
