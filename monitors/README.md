# Monitors

This directory contains the individual monitor scripts executed by the wrapper.

## Contract

Each monitor is expected to:

- run safely under the shared library in `lib/linux_maint.sh`
- emit parse-safe summary lines
- use stable `reason=` tokens documented in `docs/REASONS.md`
- avoid writing unrelated local state outside the configured paths

## Related docs

- `docs/MONITORS_MATRIX.md`
- `docs/CUSTOM_MONITORS.md`
- `docs/REASONS.md`

## Naming

Most monitor files end in `_monitor.sh`, while a small number keep legacy names such as `backup_check.sh` or `config_validate.sh`.

