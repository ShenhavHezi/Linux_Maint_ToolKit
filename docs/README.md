# Documentation index

## Operator docs (start here)

- **Quick reference (cheat-sheet)**: [`QUICK_REFERENCE.md`](QUICK_REFERENCE.md)
- **Full reference (configuration, monitors, outputs)**: [`reference.md`](reference.md)
- **Reason tokens** (`reason=` contract): [`REASONS.md`](REASONS.md)
- **Offline / dark-site usage**: [`DARK_SITE.md`](DARK_SITE.md)

## Contributor docs

- Contribution workflow and contracts: [`../CONTRIBUTING.md`](../CONTRIBUTING.md)


## Architecture and data flow

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

See details in [`reference.md`](reference.md).
