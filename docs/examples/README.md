# Examples

This folder contains minimal, copy-friendly examples for quick evaluation.

## minimal_config/

A small set of config files to bootstrap a first run in repo mode or installed mode.

Usage (repo mode):

```bash
cp -r docs/examples/minimal_config /tmp/linux_maint
export LM_CFG_DIR=/tmp/linux_maint
./bin/linux-maint run
```

Replace hostnames and service names before using in production.

## fleet_quickstart/

An SSH fleet example with inventory, services, and network targets.
