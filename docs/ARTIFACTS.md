# Artifacts and Logs

This document describes the files produced by runs and where to look for them.

## Repo mode (local checkout)

- Logs and summaries are written under `./.logs/` by default.
- Example files:
  - `./.logs/full_health_monitor_<timestamp>.log`
  - `./.logs/full_health_monitor_summary_<timestamp>.log`
  - `./.logs/full_health_monitor_summary_<timestamp>.json`
  - `./.logs/last_status_full`

## Installed mode

Default locations under `/var/log/health`:

- Full log: `full_health_monitor_<timestamp>.log` and `full_health_monitor_latest.log`
- Summary log (only `monitor=` lines): `full_health_monitor_summary_<timestamp>.log` and `full_health_monitor_summary_latest.log`
- Summary JSON: `full_health_monitor_summary_<timestamp>.json` and `full_health_monitor_summary_latest.json`

## Summary contract line

Each monitor emits a single machine‑parseable summary line per target host:

```
monitor=<name> host=<target> status=<OK|WARN|CRIT|UNKNOWN|SKIP> node=<runner> reason=<token> [key=value ...]
```

Only these `monitor=` lines are written into the summary artifacts.

## CLI accessors

- `linux-maint status` — human view based on latest summary artifacts
- `linux-maint status --verbose` — raw `monitor=` lines
- `linux-maint status --json` — automation‑friendly payload
- `linux-maint export --json|--csv` — structured output for external systems

## Retention

If installed with `--with-logrotate`, log retention is handled via logrotate.
Without logrotate, logs can grow over time; consider an explicit retention policy.

## Prometheus textfile (optional)

If enabled, the wrapper can write:

- `/var/lib/node_exporter/textfile_collector/linux_maint.prom`

This file contains counters derived from `monitor=` summary lines.
