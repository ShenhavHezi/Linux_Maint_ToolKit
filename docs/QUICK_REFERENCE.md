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

# Status JSON with redaction
LM_REDACT_JSON=1 sudo linux-maint status --json
LM_REDACT_JSON_STRICT=1 sudo linux-maint status --json

# Status as Prometheus textfile metrics
sudo linux-maint status --prom

# Unified report (status + trends + runtimes)
sudo linux-maint report
sudo linux-maint report --json
sudo linux-maint report --compact
sudo linux-maint report --short
sudo linux-maint report --table
sudo linux-maint report --redact

# Preflight + validate + expected SKIPs
sudo linux-maint check
sudo linux-maint check --json

# Run only selected monitors (names with or without _monitor)
sudo linux-maint run --only service_monitor,ntp_drift_monitor

# Skip selected monitors
sudo linux-maint run --skip inventory_export,backup_check

# Plan only (no execution)
sudo linux-maint run --plan
sudo linux-maint run --plan --json

# Interactive TUI menu (uses gum if installed, else dialog/whiptail)
sudo linux-maint menu

# List monitors and config requirements
sudo linux-maint list-monitors

# Lint a summary file
sudo linux-maint lint-summary /var/log/health/full_health_monitor_summary_latest.log

# Initialize config templates (won't overwrite unless --force)
sudo linux-maint init
sudo linux-maint init --minimal
sudo linux-maint init --force

# Run history (fast; uses run_index.jsonl)
sudo linux-maint history --last 10
sudo linux-maint history --json
sudo linux-maint history --table
sudo linux-maint history --table --no-color
sudo linux-maint history --compact

# Run index maintenance
sudo linux-maint run-index --stats
sudo linux-maint run-index --prune --keep 200

# History usage tips
# - Text view: quick skim of recent runs in terminals
# - Table view: stable columns for copy/paste into tickets
# - JSON view: automation/dashboards (parse with jq)

# One-line summary (cron/dashboards)
sudo linux-maint summary
sudo linux-maint status --summary

# Table format for problems
sudo linux-maint status --table
sudo linux-maint status --compact

# Grouped fleet summary
sudo linux-maint status --group-by host
sudo linux-maint status --group-by monitor
sudo linux-maint status --group-by reason
sudo linux-maint status --group-by host --top 10

# Compact diagnostics
sudo linux-maint doctor --compact
sudo linux-maint self-check --compact

# JSON schemas (validation)
docs/schemas/report.json
docs/schemas/history.json
docs/schemas/run_index.json

# Filter by host/monitor/status
sudo linux-maint status --host web --monitor service --only WARN

# Regex matching mode for host/monitor filters
sudo linux-maint status --host '^web-[0-9]+$' --match-mode regex

# Seed known_hosts for strict SSH mode
sudo /usr/local/libexec/linux_maint/seed_known_hosts.sh --hosts-file /etc/linux_maint/servers.txt

# Focus on recent run artifacts only
sudo linux-maint status --since 2h

# Diff since last run
sudo linux-maint diff

# Trend over recent summary runs
sudo linux-maint trend --last 10

# Trend in JSON
sudo linux-maint trend --last 10 --json
sudo linux-maint trend --last 10 --csv
sudo linux-maint trend --since 2026-02-01 --until 2026-02-24

# Monitor runtimes from wrapper logs
sudo linux-maint runtimes
sudo linux-maint runtimes --last 3 --json

# Export a unified JSON payload
sudo linux-maint export --json

# Export JSON with redaction
LM_REDACT_JSON=1 sudo linux-maint export --json

# Metrics snapshot (status + trend + runtimes)
sudo linux-maint metrics --json
sudo linux-maint metrics --prom

# Export JSON with row allowlist
LM_EXPORT_ALLOWLIST=monitor,host,status,reason sudo linux-maint export --json

# Export summary rows as CSV
sudo linux-maint export --csv

# Prometheus textfile output (written by wrapper)
# Default: /var/lib/node_exporter/textfile_collector/linux_maint.prom
# Also includes linux_maint_last_run_age_seconds
# Contract notes: status labels are stable (ok|warn|crit|unknown|skipped); reason labels are top-N only.

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

# Explain a monitor (purpose, deps, common reasons)
linux-maint explain monitor health_monitor

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
LM_PACK_LOGS_HASH=1 sudo linux-maint pack-logs --out /tmp

# Pack logs redaction control
sudo linux-maint pack-logs --out /tmp --redact
sudo linux-maint pack-logs --out /tmp --no-redact
```

## Fleet runs (monitoring node)

```bash
# Plan only (no execution)
sudo linux-maint run --group prod --plan

# Run group with parallelism
sudo linux-maint run --group prod --parallel 10

# Ad-hoc list
sudo linux-maint run --hosts server-a,server-b --exclude server-c
```

## First-run workflow (installed mode)

1. `sudo linux-maint init`
2. `sudo linux-maint run`
3. `sudo linux-maint status`
4. Review expected SKIPs: `sudo linux-maint status --expected-skips`

## Baselines (one-time)

```bash
sudo linux-maint baseline ports --update
sudo linux-maint baseline configs --update
sudo linux-maint baseline users --update
sudo linux-maint baseline sudoers --update
```

## What to check when something is wrong

1. `sudo linux-maint status --verbose`
2. `sudo linux-maint logs 200`
3. `sudo linux-maint doctor`

## Example outputs (truncated)

Color output (report):

```text
=== linux-maint report ===
Status: \x1b[32mOK\x1b[0m  (OK=18 WARN=1 CRIT=0 SKIP=2 UNKNOWN=0)
Top problems:
- service_monitor host=db-01 status=\x1b[33mWARN\x1b[0m reason=service_inactive unit=postgresql
Next steps:
- check systemctl status postgresql
```

No-color output (report):

```text
=== linux-maint report ===
Status: OK  (OK=18 WARN=1 CRIT=0 SKIP=2 UNKNOWN=0)
Top problems:
- service_monitor host=db-01 status=WARN reason=service_inactive unit=postgresql
Next steps:
- check systemctl status postgresql
```

Color output (trend):

```text
=== linux-maint trend ===
Last 10 runs: WARN=3 CRIT=1
Top reasons:
- \x1b[31msecurity_updates_pending\x1b[0m 3
- \x1b[33mservice_inactive\x1b[0m 2
```

No-color output (trend):

```text
=== linux-maint trend ===
Last 10 runs: WARN=3 CRIT=1
Top reasons:
- security_updates_pending 3
- service_inactive 2
```

Color output (diff):

```text
=== linux-maint diff ===
+ service_monitor host=db-01 status=\x1b[33mWARN\x1b[0m reason=service_inactive unit=postgresql
- ntp_drift_monitor host=web-02 status=\x1b[33mWARN\x1b[0m reason=ntp_drift_high offset_ms=412
```

No-color output (diff):

```text
=== linux-maint diff ===
+ service_monitor host=db-01 status=WARN reason=service_inactive unit=postgresql
- ntp_drift_monitor host=web-02 status=WARN reason=ntp_drift_high offset_ms=412
```

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
