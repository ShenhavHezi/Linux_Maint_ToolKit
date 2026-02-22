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
- `LM_LOCAL_ONLY=true` (force local-only; useful for CI)
- `LM_DARK_SITE=true` (optional profile for conservative defaults)

Details are in `docs/reference.md`.
