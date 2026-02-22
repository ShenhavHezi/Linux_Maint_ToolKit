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

## Recommended `reason` tokens

These are cross-monitor, reusable tokens. Prefer these before inventing a new one.

### Common
- `ssh_unreachable` — cannot reach host via SSH / command execution
- `missing_dependency` — required command missing on runner/host
- `missing_optional_cmd` — optional command missing (monitor skipped/degraded)
- `early_exit` — monitor exited without emitting a summary line (wrapper or monitor trap fallback)
- `timeout` — command timed out
- `runtime_exceeded` — monitor runtime exceeded warn threshold (wrapper guard)
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
