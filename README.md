# Linux Maintenance Scripts


## Installation (recommended Linux paths)

This layout matches common Linux conventions:
- Wrapper (entrypoint): `/usr/local/sbin/run_full_health_monitor.sh`
- Scripts (monitors): `/usr/local/libexec/linux_maint/`
- Shared library: `/usr/local/lib/linux_maint.sh`

```bash
# Clone
git clone https://github.com/ShenhavHezi/linux_Maint_Scripts.git
cd linux_Maint_Scripts

# Install
sudo install -D -m 0755 linux_maint.sh /usr/local/lib/linux_maint.sh
sudo install -D -m 0755 run_full_health_monitor.sh /usr/local/sbin/run_full_health_monitor.sh
sudo install -d /usr/local/libexec/linux_maint

# Install monitor scripts (exclude the wrapper)
sudo install -D -m 0755 \
  backup_check.sh cert_monitor.sh config_drift_monitor.sh health_monitor.sh \
  inode_monitor.sh inventory_export.sh network_monitor.sh nfs_mount_monitor.sh \
  ntp_drift_monitor.sh patch_monitor.sh ports_baseline_monitor.sh \
  service_monitor.sh user_monitor.sh \
  /usr/local/libexec/linux_maint/

# Create config/log directories
sudo mkdir -p /etc/linux_maint /etc/linux_maint/baselines /var/log/health
```


### Permissions / hardening (recommended)
After installation, keep the scripts directory root-owned and not writable by non-root users:

```bash
sudo chown -R root:root /usr/local/libexec/linux_maint
sudo chmod -R go-w /usr/local/libexec/linux_maint
```


## Installed file layout (recommended)

```text
/usr/local/sbin/run_full_health_monitor.sh
/usr/local/lib/linux_maint.sh
/usr/local/libexec/linux_maint/
  backup_check.sh
  cert_monitor.sh
  config_drift_monitor.sh
  health_monitor.sh
  inode_monitor.sh
  inventory_export.sh
  network_monitor.sh
  nfs_mount_monitor.sh
  ntp_drift_monitor.sh
  patch_monitor.sh
  ports_baseline_monitor.sh
  service_monitor.sh
  user_monitor.sh

/etc/linux_maint/
  servers.txt
  excluded.txt
  services.txt
  network_targets.txt
  certs.txt
  ports_baseline.txt
  config_paths.txt
  backup_targets.csv
  baseline_users.txt
  baseline_sudoers.txt
  baselines/

/var/log/health/
  full_health_monitor_latest.log
```


## What runs in the nightly "full package" (cron)
The system cron (root) runs the wrapper:

```bash
/usr/local/sbin/run_full_health_monitor.sh
```

That wrapper executes these scripts (in order):

- `health_monitor.sh` – snapshot: uptime, load, CPU/mem, disk usage, top processes
- `inode_monitor.sh` – inode usage thresholds
- `network_monitor.sh` – ping/tcp/http checks from `/etc/linux_maint/network_targets.txt`
- `service_monitor.sh` – critical service status from `/etc/linux_maint/services.txt`
- `ntp_drift_monitor.sh` – NTP/chrony/timesyncd sync and drift
- `patch_monitor.sh` – pending updates + reboot-required hints
- `cert_monitor.sh` – certificate expiry checks from `/etc/linux_maint/certs.txt`
- `nfs_mount_monitor.sh` – NFS mount presence + responsiveness checks
- `ports_baseline_monitor.sh` – detect new/removed listening ports vs baseline
- `config_drift_monitor.sh` – detect drift in critical config files vs baseline
- `user_monitor.sh` – detect user/sudoers anomalies vs baseline
- `backup_check.sh` – verify backups from `/etc/linux_maint/backup_targets.csv`
- `inventory_export.sh` – write daily inventory CSV under `/var/log/inventory/`

### Wrapper log output
The wrapper writes an aggregated log to:

- `/var/log/health/full_health_monitor_latest.log`

Each script prints a **single one-line summary** to stdout so the wrapper log stays readable.
Detailed logs are still written per-script under `/var/log/*.log`.

## Configuration files under `/etc/linux_maint/`
Minimal files created/used:

- `servers.txt` – hosts list (default: `localhost`)
- `excluded.txt` – optional excluded hosts
- `services.txt` – services to check
- `network_targets.txt` – network checks (CSV)
- `certs.txt` – cert targets (one per line)
- `ports_baseline.txt` – (legacy) initial ports baseline list
- `config_paths.txt` – list of critical config paths to baseline
- `baseline_users.txt` / `baseline_sudoers.txt` – initial user/sudoers baseline inputs

Baselines created by monitors:

- `/etc/linux_maint/baselines/ports/<host>.baseline`
- `/etc/linux_maint/baselines/config/<host>.baseline` (if enabled in script)
- `/etc/linux_maint/baselines/users/<host>.users`
- `/etc/linux_maint/baselines/sudoers/<host>.sudoers`


## Optional monitors: enablement examples

Some monitors are intentionally **skipped** until you provide configuration files.
This keeps first-run output clean and avoids false alerts.

### Enable `network_monitor.sh`

Create `/etc/linux_maint/network_targets.txt` (CSV):

```bash
sudo tee /etc/linux_maint/network_targets.txt >/dev/null <<'EOF'
# host,check,target,key=value...
localhost,ping,8.8.8.8,count=3,timeout=3
localhost,tcp,1.1.1.1:443,timeout=3
localhost,http,https://example.com,timeout=5,expect=200-399
EOF
```

### Enable `cert_monitor.sh`

Create `/etc/linux_maint/certs.txt` (one target per line; supports optional params after `|`):

```bash
sudo tee /etc/linux_maint/certs.txt >/dev/null <<'EOF'
# host:port
example.com:443

# SNI override (when hostname differs from certificate name)
api.example.com:443|sni=api.example.com

# STARTTLS example (if you monitor SMTP)
smtp.example.com:587|starttls=smtp
EOF
```

### Enable `backup_check.sh`

Create `/etc/linux_maint/backup_targets.csv`:

```bash
sudo tee /etc/linux_maint/backup_targets.csv >/dev/null <<'EOF'
# host,pattern,max_age_hours,min_size_mb,verify
*,/backups/db/db_*.tar.gz,24,100,tar
localhost,/var/backups/etc_*.tar.gz,48,10,gzip
EOF
```

### Enable `ports_baseline_monitor.sh`

`ports_baseline_monitor.sh` maintains per-host baselines under:
- `/etc/linux_maint/baselines/ports/<host>.baseline`

The wrapper only runs this monitor when `/etc/linux_maint/ports_baseline.txt` exists.
Create it as an (optional) “gate” file (contents are not used by the monitor):

```bash
sudo install -D -m 0644 /dev/null /etc/linux_maint/ports_baseline.txt
```

On first run, the baseline will be auto-created (when `AUTO_BASELINE_INIT=true`).

### Enable `config_drift_monitor.sh`

Create `/etc/linux_maint/config_paths.txt` with one path/pattern per line:

```bash
sudo tee /etc/linux_maint/config_paths.txt >/dev/null <<'EOF'
/etc/ssh/sshd_config
/etc/sudoers
/etc/fstab
/etc/sysctl.conf
/etc/cron.d/
EOF
```

Then run the wrapper again:

```bash
sudo /usr/local/sbin/run_full_health_monitor.sh
```


## Quick manual run
Run the full package now:

```bash
sudo /usr/local/sbin/run_full_health_monitor.sh
sudo tail -n 200 /var/log/health/full_health_monitor_latest.log
```


## Uninstall

Remove the installed files (does not remove your config/baselines unless you choose to):

```bash
# Programs
sudo rm -f /usr/local/sbin/run_full_health_monitor.sh
sudo rm -f /usr/local/lib/linux_maint.sh
sudo rm -rf /usr/local/libexec/linux_maint

# (Optional) configuration + baselines
sudo rm -rf /etc/linux_maint

# (Optional) logs
sudo rm -rf /var/log/health
sudo rm -f /var/log/*monitor*.log /var/log/*_monitor.log /var/log/*_check.log /var/log/inventory_export.log

# (Optional) logrotate entry
sudo rm -f /etc/logrotate.d/linux_maint
```


## Log rotation (recommended)

These scripts write logs under `/var/log/` (plus an aggregated wrapper log under `/var/log/health/`).
On most systems, these logs should be rotated.

Example `logrotate` config (create `/etc/logrotate.d/linux_maint`):

```conf
/var/log/*monitor*.log /var/log/*_monitor.log /var/log/*_check.log /var/log/inventory_export.log {
  daily
  rotate 14
  missingok
  notifempty
  compress
  delaycompress
  copytruncate
}

/var/log/health/*.log {
  daily
  rotate 14
  missingok
  notifempty
  compress
  delaycompress
  copytruncate
}
```

Notes:
- `copytruncate` is used so rotation is safe even if a script is still writing.
- Tune `rotate`/`daily` to match your retention needs.

## Upgrading

To upgrade on a node where you installed using the recommended paths:

```bash
cd /path/to/linux_Maint_Scripts
git pull

sudo install -D -m 0755 linux_maint.sh /usr/local/lib/linux_maint.sh
sudo install -D -m 0755 run_full_health_monitor.sh /usr/local/sbin/run_full_health_monitor.sh
sudo install -D -m 0755 *.sh /usr/local/libexec/linux_maint/
```

After upgrading:
- Review `git diff` for config file name changes.
- Re-run the wrapper once and check: `/var/log/health/full_health_monitor_latest.log`.
