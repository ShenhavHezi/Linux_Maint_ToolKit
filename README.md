# Linux Maintenance Toolkit (linux-maint)

`linux-maint` is a lightweight health and maintenance toolkit for Linux administrators.
Run it locally or from a monitoring node over SSH to get structured logs and OK/WARN/CRIT summaries.
Target: RHEL 9. Offline/dark-site friendly.

Note: this project was previously named `linux_Maint_Scripts` on GitHub. The CLI remains `linux-maint`.

## Table of Contents

- [Features](#features)
- [Quickstart](#quickstart)
- [Configuration](#configuration)
- [Documentation](#documentation)
- [Testing](#testing)
- [Contributing](#contributing)
- [License](#license)

## Features

- Standardized summary contract (`monitor=... host=... status=... reason=...`) for automation.
- Runs locally or across fleets via SSH (`/etc/linux_maint/servers.txt`).
- Hardened wrapper with timeouts, SKIP gating for optional inputs, and machine-readable artifacts.
- Optional Prometheus textfile output and JSON outputs for tooling.
- Offline/dark-site friendly (no runtime network dependency).

## Quickstart

RHEL 9 (repo mode):

```bash
git clone https://github.com/ShenhavHezi/Linux_Maint_ToolKit.git
cd Linux_Maint_ToolKit
sudo ./run_full_health_monitor.sh
sudo ./bin/linux-maint status
```

For installed mode and timers, see `docs/installation.md`.

## Configuration

Config templates live in `etc/linux_maint/*.example` and are installed to `/etc/linux_maint/`.
Start here:
- `etc/linux_maint/README.md`
- `docs/configuration.md`

## Documentation

- Docs index: `docs/README.md`
- Full reference (monitors, outputs, contracts): `docs/reference.md`
- Installation: `docs/installation.md`
- Troubleshooting: `docs/troubleshooting.md`

## Testing

```bash
bash tests/smoke.sh
bash tests/summary_contract.sh  # when touching summary/json/monitor output
```

## Contributing

See `CONTRIBUTING.md` and `AGENTS.MD`.

## License

See `LICENSE`.
