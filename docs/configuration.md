# Configuration

This page explains the primary configuration entrypoints and first-run behavior.
For full reference, see `docs/reference.md`.

## Where config lives

Templates are in `etc/linux_maint/*.example`.
Installed configs live in `/etc/linux_maint/`.

Quick overview of templates: `etc/linux_maint/README.md`.

## The first three files to touch

- `servers.txt` — target hosts for SSH mode
- `services.txt` — services to verify
- `network_targets.txt` — optional reachability checks (if missing/empty, wrapper emits `SKIP` for `network_monitor`)

Dark-site tip:
- In air-gapped environments, keep `network_targets.txt` absent until you have internal targets to test; `network_monitor` will be auto-skipped with a clear `reason=missing:...` summary line.

## Common knobs (short list)

- `MONITOR_TIMEOUT_SECS` (default `600`)
- `LM_NOTIFY` (wrapper-level per-run email summary; default `0` / off)
- `LM_SSH_OPTS` (e.g. `-o BatchMode=yes -o ConnectTimeout=3`)
- `LM_SSH_ALLOWLIST` (optional regex allowlist for SSH commands; blocks non-matching)
- `LM_LOCAL_ONLY=true` (force local-only; useful for CI)
- `LM_DARK_SITE=true` (optional profile for conservative defaults)
- `LM_MAX_PARALLEL` (max parallel SSH fan-out)
- `LM_MAX_PARALLEL_CAP` (safety cap for LM_MAX_PARALLEL; default 25)
- `LM_TREND_CACHE=1` (opt-in cache for `linux-maint trend`)
- `LM_TREND_CACHE_TTL=60` (seconds to reuse cached trend output)
- `LM_INVENTORY_CACHE=1` (opt-in cache for `inventory_export`)
- `LM_INVENTORY_CACHE_TTL=3600` (seconds to reuse cached inventory data)
- `LM_INVENTORY_CACHE_DIR=/var/log/inventory/cache` (optional override for inventory cache)
- `LM_SSH_TIMEOUT=30` (optional hard timeout for ssh commands when `timeout` exists)

Details are in `docs/reference.md`.

## SSH allowlist (optional)

If you want to restrict remote commands, set `LM_SSH_ALLOWLIST` in `/etc/linux_maint/linux-maint.conf`.
This is a comma/space-separated list of regex patterns; a command must match at least one pattern.

Example:

```bash
# /etc/linux_maint/linux-maint.conf
LM_SSH_ALLOWLIST='^bash -lc |^command -v |^df |^ss |^netstat |^systemctl |^ping |^nc |^curl |^timeout |^chronyc |^ntpq |^timedatectl |^mountpoint |^stat |^uname '
```

Start broad, then tighten based on blocked-command warnings.
