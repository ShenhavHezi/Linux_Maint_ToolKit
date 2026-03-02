# Fleet quickstart example

This example shows a minimal SSH-based fleet setup with services and network targets.

Files included:
- `servers.txt` — inventory of SSH targets
- `services.txt` — systemd service names to monitor
- `network_targets.txt` — ping/tcp/http checks (CSV format)

## Usage (repo mode)

```bash
cp -r docs/examples/fleet_quickstart /tmp/linux_maint
export LM_CFG_DIR=/tmp/linux_maint
sudo ./bin/linux-maint run
```

Edit the hostnames, services, and targets to match your environment before use.
