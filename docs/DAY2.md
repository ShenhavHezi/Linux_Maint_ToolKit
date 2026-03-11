# Day-2 Maintenance

This page covers routine maintenance after rollout: patching, baseline refresh, runtime tuning, and trend review.

## Patch and verify

```bash
linux-maint status --reasons 5
sudo dnf update -y
linux-maint run
linux-maint status
linux-maint diff
```

Use your own distro package workflow if you are not on RHEL-like systems.

## Baseline refresh after approved changes

Update baselines only after the new state is accepted.

Ports baseline:

```bash
linux-maint run
# then enable the baseline update path for ports and re-run
```

Config drift baseline:

```bash
linux-maint run
# then enable the baseline update path for config drift and re-run
```

User and sudoers baselines:

```bash
linux-maint baseline users --update
linux-maint baseline sudoers --update
```

## Runtime tuning

```bash
linux-maint runtimes --last 3
sudo tee /etc/linux_maint/monitor_runtime_warn.conf >/dev/null <<'EOF'
network_monitor=30
backup_check=120
EOF
```

Then rerun and confirm the threshold behavior is useful.

## Trend and regression review

```bash
linux-maint trend --last 10
linux-maint diff
linux-maint history --last 10 --table
```

## Support and escalation

```bash
linux-maint doctor
linux-maint pack-logs --out /tmp
```

## Companion docs

- [RUNBOOK.md](RUNBOOK.md)
- [troubleshooting.md](troubleshooting.md)
- [ARTIFACTS.md](ARTIFACTS.md)
- [REASONS.md](REASONS.md)
