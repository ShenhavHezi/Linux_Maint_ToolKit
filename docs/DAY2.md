# Day-2 Operations Guide

This guide covers routine operations after initial rollout.

## Patching flow

1. Review status:

```bash
sudo linux-maint status --reasons 5
```

2. Apply patches using your distro tooling (example):

```bash
sudo dnf update -y
```

3. Re-run and confirm:

```bash
sudo linux-maint run
sudo linux-maint status
```

## Baseline refresh

### Ports baseline

- If you expect a known change in listening ports, update the baseline:

```bash
sudo linux-maint run
# then set BASELINE_UPDATE=true in /etc/linux_maint/ports_baseline_monitor.conf and re-run
```

### Config drift baseline

- For accepted config changes, update baseline:

```bash
sudo linux-maint run
# then set BASELINE_UPDATE=true in /etc/linux_maint/config_drift_monitor.conf and re-run
```

## Runtime warn tuning

1. Identify slow monitors:

```bash
linux-maint runtimes --last 3
```

2. Add thresholds:

```bash
sudo tee /etc/linux_maint/monitor_runtime_warn.conf >/dev/null <<'EOF2'
network_monitor=30
backup_check=120
EOF2
```

3. Validate warnings appear when thresholds are exceeded.

## Trend and regression review

```bash
sudo linux-maint trend --last 10
sudo linux-maint diff
```

## Support bundle

```bash
sudo linux-maint pack-logs --out /tmp
```

