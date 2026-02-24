# linux-maint `reason=` vocabulary (contract)

This project emits machine-parseable summary lines of the form:

```
monitor=<name> host=<host> status=<OK|WARN|CRIT|UNKNOWN|SKIP> node=<runner> [reason=<token>] [key=value ...]
```

`reason=` is a **stable token** intended for:

- alert routing / deduplication
- dashboards
- run-to-run diffs
- regression tests

## Rules (contract)

- Allowed `status` values: `OK`, `WARN`, `CRIT`, `UNKNOWN`, `SKIP`.
- `monitor=` lines should be emitted **at least once per executed monitor**.
- For non-OK statuses (`WARN|CRIT|UNKNOWN|SKIP`), include `reason=`.
  - If a script truly cannot determine a reason, use `reason=unknown` (avoid omitting).
- `reason` values are **lower_snake_case**.
- Optional `next_step=<token>` may be emitted for common `reason=` values to suggest remediation.

## Recommended `reason` tokens

These are cross-monitor, reusable tokens. Prefer these before inventing a new one.

## Top 10 reasons (quick reference)

These are the most common operator-facing reasons. Use them for first-line triage:

- `missing_dependency` — required command missing on runner/host
- `missing_optional_cmd` — optional command missing (monitor skipped/degraded)
- `ssh_unreachable` — cannot reach host via SSH / command execution
- `service_failed` — systemd unit in failed state
- `service_inactive` — systemd unit inactive/disabled
- `timeout` — command timed out
- `config_missing` — required config file missing
- `baseline_missing` — baseline not found (expected on first run)
- `security_updates_pending` — security updates available
- `timer_missing` — systemd timer unit not installed

Suggested first actions:
- `missing_dependency`: install the listed tool on the runner or target host.
- `missing_optional_cmd`: install the optional tool or accept the SKIP until needed.
- `ssh_unreachable`: verify DNS, keys, firewall, and `LM_SSH_OPTS`.
- `service_failed`: check `systemctl status <unit>` and recent logs.
- `service_inactive`: enable or start the unit if required for your environment.
- `timeout`: increase `MONITOR_TIMEOUT_SECS` or per-monitor timeouts, then re-run.
- `config_missing`: run `sudo linux-maint init` and populate the file.
- `baseline_missing`: generate the baseline or allow baseline auto-init where supported.
- `security_updates_pending`: run your distro update workflow, then re-check.
- `timer_missing`: install/enable `linux-maint.timer` in installed mode.

### Common
- `ssh_unreachable` — cannot reach host via SSH / command execution
- `missing_dependency` — required command missing on runner/host
- `missing_optional_cmd` — optional command missing (monitor skipped/degraded)
- `early_exit` — monitor exited without emitting a summary line (wrapper or monitor trap fallback)
- `timeout` — command timed out
- `runtime_exceeded` — monitor runtime exceeded warn threshold (wrapper guard)
- `summary_invalid` — strict wrapper validation failed due to malformed summary line(s)
- `not_installed` — required tool/service missing
- `permission_denied` — permission problem reading state/logs/etc
- `config_missing` — required config file missing
- `config_invalid` — config present but invalid/unparseable
- `unsupported` — environment unsupported (distro/tooling)
- `baseline_created` — baseline created from current snapshot
- `baseline_updated` — baseline updated to current snapshot
- `baseline_exists` — baseline already present (no change)
- `baseline_collect_failed` — unable to collect baseline data
- `timer_missing` — systemd timer unit not installed
- `timer_disabled` — systemd timer present but disabled
- `timer_inactive` — systemd timer enabled but not active
- `missing_last_run_log` — expected wrapper log not found
- `stale_run` — wrapper log too old (run likely missed)

### Storage / disk
- `disk_full` — hard threshold exceeded
- `disk_growth` — growth forecast exceeded
- `inode_high` — inode usage exceeded threshold
- `filesystem_readonly` — filesystem remounted read-only
- `smart_failed` — SMART indicates failure
- `raid_degraded` — mdraid degraded

### Time
- `ntp_not_synced`
- `ntp_drift_high`

### Patching
- `updates_pending`
- `security_updates_pending`
- `reboot_required`

### Services / processes
- `service_inactive`
- `service_failed`
- `high_load`
- `high_mem`

### Network
- `ping_failed`
- `tcp_failed`
- `http_failed`

### Logs
- `log_spike_warn` — log error rate above warn threshold
- `log_spike_crit` — log error rate above crit threshold
- `missing_log_source` — no usable journald/syslog/messages source available

### Security
- `failed_ssh_logins`
- `unexpected_user`
- `unexpected_sudoers_change`

### TLS/certs
- `cert_expiring`
- `cert_invalid`

## Adding new reasons

1. Add the token here.
2. Prefer reusing an existing token.
3. Keep tokens stable once introduced.
