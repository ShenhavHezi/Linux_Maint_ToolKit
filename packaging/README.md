# Packaging

This directory contains packaging assets for distributing `linux-maint`.

## Current packaging targets

- `rpm/` — RPM spec, systemd units, and build helper for Rocky/RHEL-style packaging.

## Notes

- Tarball release creation is handled by the top-level release tooling in `tools/`.
- RPM packaging assets live here because they are distribution-specific and should stay separate from the generic install flow in `install.sh`.

