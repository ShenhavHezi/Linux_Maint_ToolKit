# Minimal Config Example

This directory contains a small, copy-friendly example config set for first runs.

## Intended use

```bash
cp -r docs/examples/minimal_config /tmp/linux_maint
export LM_CFG_DIR=/tmp/linux_maint
./bin/linux-maint run --plan
./bin/linux-maint run
```

Update the hosts, services, baselines, and paths before using it on a real system.

