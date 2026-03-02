# Custom Monitors

This guide explains how to add your own monitor scripts and keep their output compatible with the Linux_Maint_ToolKit contract.

## Quick start

1. Generate a template:

```bash
tools/new_monitor.sh my_custom_monitor
```

2. Edit the new script under `monitors/` and implement your checks.
3. Run it locally:

```bash
bash monitors/my_custom_monitor.sh
```

4. Run via the wrapper:

```bash
sudo linux-maint run --only my_custom_monitor
```

## Summary contract (required)

Every monitor must emit at least one `monitor=` summary line using `lm_summary`:

```bash
lm_summary "my_custom_monitor" "$host" "OK"
```

Contract notes:
- Required keys: `monitor`, `host`, `status`, `node`
- Non-OK statuses must include a `reason=` token (the library adds one if missing).
- Do not include whitespace in values (use `_` or `-`).

## Config files

If your monitor depends on config files under `/etc/linux_maint`, use `LM_CFG_DIR` for portability:

```bash
CONFIG_FILE="${LM_CFG_DIR:-/etc/linux_maint}/my_targets.txt"
```

The `linux-maint list-monitors` command parses monitor scripts to show config file references.

## Common helper patterns

- Per-host loop:

```bash
for host in $(lm_hosts); do
  # lm_ssh "$host" "command"
  lm_summary "my_custom_monitor" "$host" "OK"
done
```

- Dependency checks:

```bash
lm_require_cmd "my_custom_monitor" "localhost" awk || exit $?
```

## Testing tips

- Add unit checks under `tests/` if you introduce new behaviors.
- Use `linux-maint lint-summary <summary_log>` to validate your summary output.
