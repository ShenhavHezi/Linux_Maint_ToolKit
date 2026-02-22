# linux-maint — Operator Quick Reference

This page is meant for day-to-day operational use. In installed mode, most commands require `sudo`.

## Common commands

```bash
# Run full suite (installed mode)
sudo linux-maint run

# Quick health view (compact)
sudo linux-maint status

# Show expected SKIPs based on missing optional config
sudo linux-maint status --expected-skips

# Show more problems (max 100)
sudo linux-maint status --problems 100

# Top reason tokens (non-OK only)
sudo linux-maint status --reasons 5

# Raw summary lines
sudo linux-maint status --verbose

# Status in JSON (automation)
sudo linux-maint status --json

# Unified report (status + trends + runtimes)
sudo linux-maint report
sudo linux-maint report --json
sudo linux-maint report --compact
sudo linux-maint report --table

# Preflight + validate + expected SKIPs
sudo linux-maint check

# Run history (fast; uses run_index.jsonl)
sudo linux-maint history --last 10
sudo linux-maint history --json
sudo linux-maint history --table
sudo linux-maint history --table --no-color
sudo linux-maint history --compact

# One-line summary (cron/dashboards)
sudo linux-maint summary
sudo linux-maint status --summary

# Table format for problems
sudo linux-maint status --table
sudo linux-maint status --compact

# Compact diagnostics
sudo linux-maint doctor --compact
sudo linux-maint self-check --compact

# JSON schemas (validation)
docs/schemas/report.json
docs/schemas/history.json

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

# Export a unified JSON payload
sudo linux-maint export --json

# Export summary rows as CSV
sudo linux-maint export --csv

# Prometheus textfile output (written by wrapper)
# Default: /var/lib/node_exporter/textfile_collector/linux_maint.prom
# Also includes linux_maint_last_run_age_seconds

# Diff in JSON (automation)
sudo linux-maint diff --json

# Latest logs
sudo linux-maint logs 200

# Diagnostics
sudo linux-maint doctor
sudo linux-maint doctor --fix
sudo linux-maint doctor --fix --dry-run

# Diagnostics (JSON for automation)
sudo linux-maint doctor --json

# Quick self-check (safe without sudo)
linux-maint self-check
# Self-check in JSON
linux-maint self-check --json
# Verify offline tarball checksum
linux-maint verify-release Linux_Maint_ToolKit-*.tgz --sums SHA256SUMS

# Explain a reason token quickly
linux-maint explain reason ssh_unreachable

# Per-command help
linux-maint help status

# Offline dependency manifest (required vs optional tools)
sudo linux-maint deps

# Config linting (detect invalid lines / duplicates)
sudo linux-maint config --lint

# Baseline workflows
sudo linux-maint baseline ports --update
sudo linux-maint baseline configs --update
sudo linux-maint baseline users --update
sudo linux-maint baseline sudoers --update

# Progress controls (force disable)
LM_PROGRESS=0 sudo linux-maint run
LM_PROGRESS=0 sudo linux-maint pack-logs --out /tmp

# Pack logs redaction control
sudo linux-maint pack-logs --out /tmp --redact
sudo linux-maint pack-logs --out /tmp --no-redact
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

## Troubleshooting decision tree

1. If `status` shows `CRIT`:
   `sudo linux-maint status --verbose`
2. If the issue is new or unclear:
   `sudo linux-maint diff`
3. If the issue is config- or dependency-related:
   `sudo linux-maint doctor`
4. If you need a shareable bundle:
   `sudo linux-maint pack-logs --out /tmp`

## Artifacts (installed mode)

- Full log: `/var/log/health/full_health_monitor_latest.log`
- Summary log: `/var/log/health/full_health_monitor_summary_latest.log`
- Summary JSON: `/var/log/health/full_health_monitor_summary_latest.json`
- Last status file: `/var/log/health/last_status_full`
