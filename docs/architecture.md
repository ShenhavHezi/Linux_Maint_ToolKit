# Architecture

High-level structure and data flow. See `docs/reference.md` for full contracts and outputs.

## Repo map (where to look)

- Run wrapper: `run_full_health_monitor.sh`
- CLI: `bin/linux-maint` (installed as `linux-maint`)
- Monitors: `monitors/` (each emits `monitor=... status=...` summary lines)
- Shared Bash library: `lib/linux_maint.sh`
- Config templates: `etc/linux_maint/` (copy to `/etc/linux_maint/`)
- Operator docs: `docs/`
- Tools (release/lint helpers): `tools/`
- Tests: `tests/`

## Data flow

```text
linux-maint (CLI)
  ├─ run -> run_full_health_monitor.sh (wrapper)
  │        ├─ loads lib/linux_maint.sh + config
  │        ├─ executes monitors/*.sh
  │        ├─ captures monitor=... summary lines
  │        ├─ writes summary log + summary json
  │        └─ writes run metadata (last_status_full)
  └─ status/doctor/logs -> read artifacts and render operator views
```

Primary artifact flow:
- Monitors emit contract lines (`monitor=... host=... status=... reason=...`).
- Wrapper aggregates lines into timestamped summary files and latest symlinks.
- CLI status/reporting commands parse those artifacts for human and JSON outputs.
