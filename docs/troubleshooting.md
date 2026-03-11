# Troubleshooting

This page covers common operator workflows, expected first-run SKIPs, and quick fixes.
For full CLI reference, see `docs/reference.md`.

## Fastest incident path

If you are under time pressure, use this order:

1. `linux-maint status --verbose`
2. `linux-maint doctor`
3. `linux-maint diff`
4. `linux-maint pack-logs --out /tmp`

If you prefer the menu:

1. `linux-maint menu`
2. `Overview`
3. `Triage`
4. `Share`

## How to read the examples

- Examples below use repo-mode form: `linux-maint ...`
- In installed mode, prepend `sudo` when the command needs access to root-owned config, logs, or state.
- `<cfg_dir>` means your effective config root: repo fallback config in repo mode, `/etc/linux_maint` in installed mode unless overridden.

## Common operator workflows

### Run and review (repo mode)

```bash
./bin/linux-maint run
./bin/linux-maint status
```

### Run and review (installed mode)

```bash
sudo linux-maint run
sudo linux-maint status
```

### Run a fleet (SSH / monitoring node)

```bash
linux-maint run --group prod --parallel 10
linux-maint status
```

### See what changed since last run

```bash
linux-maint diff
```

### Troubleshoot / gather support bundle (offline-friendly)

```bash
linux-maint doctor
linux-maint doctor --json
linux-maint self-check
linux-maint deps
linux-maint export --json
linux-maint export --csv
linux-maint pack-logs --out /tmp
# or open: linux-maint menu -> Share -> pack logs
```

For a support-ready escalation, also include:

- `linux-maint version`
- the active mode: repo or installed
- distro and shell version
- the bundle handoff note in `meta/support_handoff.txt`

## First run expectations (normal SKIPs)

On a fresh repo or install, it’s normal to see `status=SKIP` for monitors that need optional inputs:

- `network_monitor` — missing `<cfg_dir>/network_targets.txt`
- `cert_monitor` — missing `<cfg_dir>/certs.txt`
- `ports_baseline_monitor` — missing `<cfg_dir>/ports_baseline.txt`
- `config_drift_monitor` — missing `<cfg_dir>/config_paths.txt`
- `user_monitor` — missing `<cfg_dir>/baseline_users.txt` or `baseline_sudoers.txt`
- `backup_check` — missing `<cfg_dir>/backup_targets.csv`

These SKIPs are expected until you populate the files. Use `linux-maint doctor` for fix suggestions.

## Common fixes (quick reference)

- `ssh_unreachable`: confirm host is reachable, SSH keys are valid, and firewall allows port 22.
- `missing_dependency`: install the missing tool listed in the summary (e.g., `curl`, `smartctl`).
- `missing_optional_cmd`: install the optional tool (e.g., `chronyc`/`ntpq`) or accept the SKIP.
- `config_missing`: run `linux-maint init` in repo mode or `sudo linux-maint init` in installed mode, then populate the missing file.
- `baseline_missing`: allow baseline auto-init or create baseline files under `<cfg_dir>/baselines/`.
- `service_failed`: check `systemctl status <unit>` and recent journal logs.
- `security_updates_pending`: run your distro update command and re-check.
- `log_spike_warn`: review recent logs for the monitor's target and tune thresholds/ignore lists if expected.
- `summary_write_failed` / `summary_checksum_failed`: confirm the active log dir is writable and has free space (`.logs/` in repo mode, `/var/log/health` in installed mode by default).

## How to read results (quick)

Example compact status output:

```text
$ linux-maint status
...
=== Summary (compact) ===
totals: CRIT=1 WARN=2 UNKNOWN=0 SKIP=1 OK=14

problems:
CRIT ntp_drift_monitor host=server-a reason=ntp_drift_high
WARN patch_monitor host=server-a reason=security_updates_pending
SKIP backup_check host=server-a reason=missing_targets_file
```

Tips:
- `linux-maint status --verbose` for raw summary lines
- `linux-maint diff` to show changes since the last run
- `linux-maint status --problems 100` to list more problems (max 100)
- `linux-maint status --reasons 5` to show top reason tokens
- `linux-maint status --host web --monitor service --only WARN` to narrow output
- `linux-maint status --since 2h` to focus on recent artifacts
- `linux-maint status --host '^web-[0-9]+$' --match-mode regex` for regex targeting
- `linux-maint status --json` for automation output

## Automation-friendly JSON outputs

- `linux-maint status --json`
- `linux-maint report --json`
- `linux-maint history --last N --json`
- `linux-maint trend --json`
- `linux-maint runtimes --json`
- `linux-maint export --json`
- `linux-maint export --csv`

See `docs/reference.md` for contracts and schemas.
