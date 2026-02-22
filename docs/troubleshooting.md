# Troubleshooting

This page covers common operator workflows, expected first-run SKIPs, and quick fixes.
For full CLI reference, see `docs/reference.md`.

## Common operator workflows

### Run and review (single host)

```bash
sudo ./run_full_health_monitor.sh
sudo ./bin/linux-maint status
```

### Run a fleet (SSH / monitoring node)

```bash
sudo linux-maint run --group prod --parallel 10
sudo linux-maint status
```

### See what changed since last run

```bash
sudo linux-maint diff
```

### Troubleshoot / gather support bundle (offline-friendly)

```bash
sudo linux-maint doctor
sudo linux-maint doctor --json
linux-maint self-check
sudo linux-maint deps
sudo linux-maint export --json
sudo linux-maint export --csv
sudo linux-maint pack-logs --out /tmp
```

## First run expectations (normal SKIPs)

On a fresh install, it’s normal to see `status=SKIP` for monitors that need optional inputs:

- `network_monitor` — missing `/etc/linux_maint/network_targets.txt`
- `cert_monitor` — missing `/etc/linux_maint/certs.txt`
- `ports_baseline_monitor` — missing `/etc/linux_maint/ports_baseline.txt`
- `config_drift_monitor` — missing `/etc/linux_maint/config_paths.txt`
- `user_monitor` — missing `/etc/linux_maint/baseline_users.txt` or `baseline_sudoers.txt`
- `backup_check` — missing `/etc/linux_maint/backup_targets.csv`

These SKIPs are expected until you populate the files. Use `linux-maint doctor` for fix suggestions.

## Common fixes (quick reference)

- `ssh_unreachable`: confirm host is reachable, SSH keys are valid, and firewall allows port 22.
- `missing_dependency`: install the missing tool listed in the summary (e.g., `curl`, `smartctl`).
- `missing_optional_cmd`: install the optional tool (e.g., `chronyc`/`ntpq`) or accept the SKIP.
- `config_missing`: run `sudo linux-maint init` and populate the missing file.
- `baseline_missing`: allow baseline auto-init or create baseline files under `/etc/linux_maint/baselines/`.
- `service_failed`: check `systemctl status <unit>` and recent journal logs.
- `security_updates_pending`: run your distro update command and re-check.
- `log_spike_warn`: review recent logs for the monitor's target and tune thresholds/ignore lists if expected.
- `summary_write_failed` / `summary_checksum_failed`: confirm `/var/log/health` is writable and has free space.

## How to read results (quick)

Example compact status output:

```text
$ sudo linux-maint status
...
=== Summary (compact) ===
totals: CRIT=1 WARN=2 UNKNOWN=0 SKIP=1 OK=14

problems:
CRIT ntp_drift_monitor host=server-a reason=ntp_drift_high
WARN patch_monitor host=server-a reason=security_updates_pending
SKIP backup_check host=server-a reason=missing_targets_file
```

Tips:
- `sudo linux-maint status --verbose` for raw summary lines
- `sudo linux-maint diff` to show changes since the last run
- `sudo linux-maint status --problems 100` to list more problems (max 100)
- `sudo linux-maint status --reasons 5` to show top reason tokens
- `sudo linux-maint status --host web --monitor service --only WARN` to narrow output
- `sudo linux-maint status --since 2h` to focus on recent artifacts
- `sudo linux-maint status --host '^web-[0-9]+$' --match-mode regex` for regex targeting
- `sudo linux-maint status --json` for automation output

## Automation-friendly JSON outputs

- `linux-maint status --json`
- `linux-maint report --json`
- `linux-maint history --last N --json`
- `linux-maint trend --json`
- `linux-maint runtimes --json`
- `linux-maint export --json`
- `linux-maint export --csv`

See `docs/reference.md` for contracts and schemas.
