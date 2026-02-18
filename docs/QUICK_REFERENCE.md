# linux-maint — Operator Quick Reference

This page is meant for day-to-day operational use.

## Common commands

```bash
# Run full suite (installed mode)
sudo linux-maint run

# Quick health view (compact)
sudo linux-maint status

# Show more problems (max 100)
sudo linux-maint status --problems 100

# Top reason tokens (non-OK only)
sudo linux-maint status --reasons 5

# Raw summary lines
sudo linux-maint status --verbose

# Filter by host/monitor/status
sudo linux-maint status --host web --monitor service --only WARN

# Regex matching mode for host/monitor filters
sudo linux-maint status --host '^web-[0-9]+$' --match-mode regex

# Focus on recent run artifacts only
sudo linux-maint status --since 2h

# Diff since last run
sudo linux-maint diff


# Trend over recent summary runs
sudo linux-maint trend --last 10

# Trend in JSON
sudo linux-maint trend --last 10 --json

# Monitor runtimes from wrapper logs
sudo linux-maint runtimes
sudo linux-maint runtimes --last 3 --json

# Diff in JSON (automation)
sudo linux-maint diff --json

# Latest logs
sudo linux-maint logs 200

# Diagnostics
sudo linux-maint doctor

# Diagnostics (JSON for automation)
sudo linux-maint doctor --json


# Verify offline tarball checksum
linux-maint verify-release linux_Maint_Scripts-*.tgz --sums SHA256SUMS

# Explain a reason token quickly
linux-maint explain reason ssh_unreachable

# Offline dependency manifest (required vs optional tools)
sudo linux-maint deps
```

## Fleet runs (monitoring node)

```bash
# Plan only (no execution)
sudo linux-maint run --group prod --dry-run

# Run group with parallelism
sudo linux-maint run --group prod --parallel 10

# Ad-hoc list
sudo linux-maint run --hosts server-a,server-b --exclude server-c
```

## What to check when something is wrong

1. `sudo linux-maint status --verbose`
2. `sudo linux-maint logs 200`
3. `sudo linux-maint doctor`

## Artifacts (installed mode)

- Full log: `/var/log/health/full_health_monitor_latest.log`
- Summary log: `/var/log/health/full_health_monitor_summary_latest.log`
- Summary JSON: `/var/log/health/full_health_monitor_summary_latest.json`
- Last status file: `/var/log/health/last_status_full`
