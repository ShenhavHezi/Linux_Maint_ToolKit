# Documentation index

Note: this repo was previously named `linux_Maint_Scripts`. The CLI remains `linux-maint`.

## Operator docs (start here)

- **Quick reference (cheat-sheet)**: [`QUICK_REFERENCE.md`](QUICK_REFERENCE.md)
- **Full reference (configuration, monitors, outputs)**: [`reference.md`](reference.md)
- **Reason tokens** (`reason=` contract): [`REASONS.md`](REASONS.md)
- **Offline / dark-site usage**: [`DARK_SITE.md`](DARK_SITE.md)
- **Day-2 operations**: [`DAY2.md`](DAY2.md)

## Which mode should I use?

- **Repo mode** (`./run_full_health_monitor.sh`, `./bin/linux-maint`): best for evaluation, local development, and quick trials.
- **Installed mode** (`linux-maint`, systemd timer/cron): best for scheduled production runs.

If you’re not sure, start in repo mode and install once you like the results.

## Contributor docs

- Contribution workflow and contracts: [`../CONTRIBUTING.md`](../CONTRIBUTING.md)
- Release checklist: [`RELEASE_CHECKLIST.md`](RELEASE_CHECKLIST.md)

## Dev container (optional)

If you want a consistent test environment, use the dev container:

```bash
./tools/dev_container.sh build
./tools/dev_container.sh test
```

See `containers/dev.Dockerfile` and `tools/dev_container.sh`.


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
