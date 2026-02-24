# Operations Quickstart (first 10 minutes)

This guide is a short, operator‑friendly runbook for getting meaningful output fast.

## 1) Install (recommended installed mode)

From a repo checkout:

```bash
sudo ./install.sh --with-user --with-timer --with-logrotate
```

Verify layout and paths:

```bash
sudo linux-maint verify-install
```

## 2) Initialize minimal config

```bash
sudo linux-maint init --minimal
```

Edit the three files created under `/etc/linux_maint/`:
- `servers.txt` — target hosts for SSH mode
- `excluded.txt` — optional exclusions
- `services.txt` — systemd units to verify

## 3) First run (local + SSH targets)

```bash
sudo linux-maint run
sudo linux-maint status
```

If you see `status=SKIP` entries, they usually mean optional config is missing. That is expected on a first run.

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

## 6) Dry‑run a fleet

```bash
sudo linux-maint run --group prod --dry-run
```

## 7) Common next fixes

- `reason=missing_dependency` → install the missing command on the target.
- `reason=config_missing` → populate the referenced config file under `/etc/linux_maint/`.
- `reason=baseline_missing` → create or allow baseline auto‑init where supported.

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

## 10) Repo mode (if you are not installed)

```bash
sudo ./run_full_health_monitor.sh
sudo ./bin/linux-maint status
```

## 11) Reference docs

- Full configuration and monitor reference: `docs/reference.md`
- Reason token glossary: `docs/REASONS.md`
- Offline/dark‑site guide: `docs/DARK_SITE.md`
- Upgrade and rollback: `docs/UPGRADE.md`
- Reasons quick reference (top 10): `docs/REASONS.md#top-10-reasons-quick-reference`
