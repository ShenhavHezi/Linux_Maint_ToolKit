# Configuration templates (`/etc/linux_maint`)

This directory contains **example** configuration files. When installed, templates are copied into:

- `/etc/linux_maint/` (main config dir)

## Typical files to edit first

- `servers.txt` — target hosts for SSH/distributed mode
- `services.txt` — services to verify (service monitor)
- `network_targets.txt` — optional reachability targets
- `linux-maint.conf` — wrapper/CLI configuration (optional; enables/overrides defaults)
- `monitor_runtime_warn.conf` — optional per-monitor runtime warning thresholds

## Notes

- Files here end with `.example`. Copy them to `/etc/linux_maint/` and remove the suffix.
- Many monitors are **gated** by the presence of certain baselines/lists; when missing, monitors typically emit `status=SKIP` with a `reason=` token (see `docs/REASONS.md`).
- New monitors added in 2026 are configurable via `LM_LAST_RUN_MAX_AGE_MIN`, `LM_LAST_RUN_LOG_DIR`, and `LM_FS_RO_EXCLUDE_RE` in `linux-maint.conf`.
