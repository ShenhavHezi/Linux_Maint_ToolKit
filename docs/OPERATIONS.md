# Operations Quickstart (first 10 minutes)

This guide is a short, operator‑friendly runbook for getting meaningful output fast.

## 1) Run locally (repo mode)

```bash
sudo ./run_full_health_monitor.sh
sudo ./bin/linux-maint status
```

If you see `status=SKIP` entries, they usually mean optional config is missing. That is expected on a first run.

## 2) Initialize minimal config

```bash
sudo ./bin/linux-maint init --minimal
```

Edit the three files created under `/etc/linux_maint/`:
- `servers.txt` — target hosts for SSH mode
- `excluded.txt` — optional exclusions
- `services.txt` — systemd units to verify

## 3) Dry‑run a fleet

```bash
sudo linux-maint run --group prod --dry-run
```

## 4) Validate and preflight

```bash
sudo linux-maint check
```

This runs config validation, preflight dependency checks, and prints expected SKIPs.

## 5) Review results

```bash
sudo linux-maint status
sudo linux-maint status --verbose
sudo linux-maint status --json
```

## 6) Common next fixes

- `reason=missing_dependency` → install the missing command on the target.
- `reason=config_missing` → populate the referenced config file under `/etc/linux_maint/`.
- `reason=baseline_missing` → create or allow baseline auto‑init where supported.

## 7) Install for scheduled runs (optional)

```bash
sudo ./install.sh --with-user --with-timer --with-logrotate
```

## 8) First‑run expected SKIPs

Run this to confirm optional gates:

```bash
sudo linux-maint status --expected-skips
```

## 9) Troubleshooting bundle (offline‑friendly)

```bash
sudo linux-maint doctor
sudo linux-maint pack-logs --out /tmp
```

## 10) Reference docs

- Full configuration and monitor reference: `docs/reference.md`
- Reason token glossary: `docs/REASONS.md`
- Offline/dark‑site guide: `docs/DARK_SITE.md`
