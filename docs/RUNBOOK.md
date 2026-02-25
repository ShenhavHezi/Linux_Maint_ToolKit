# Operator runbook (short)

This is a minimal, practical workflow for first-time setup and day-2 operations.

## 1) Install (installed mode)

```bash
sudo ./install.sh
sudo linux-maint init
```

If you are running from a repo checkout (no install), you can still use `linux-maint` directly, but the default paths live under the repo.

## 2) First run (safe baseline)

```bash
sudo linux-maint run
sudo linux-maint status
```

If you see `SKIP` entries for optional configs, that is expected. Use:

```bash
sudo linux-maint status --expected-skips
```

## 3) Create baselines (one-time)

Baselines are required for the following monitors:
- ports baseline
- config drift baseline
- user/sudoers baseline

Generate them after the system is in a known-good state:

```bash
sudo linux-maint baseline ports --update
sudo linux-maint baseline configs --update
sudo linux-maint baseline users --update
sudo linux-maint baseline sudoers --update
```

## 4) Day-2 checks (regular)

Daily:
```bash
sudo linux-maint status
sudo linux-maint report --short
```

Weekly:
```bash
sudo linux-maint trend --last 10
sudo linux-maint runtimes --last 3
```

When something fails:
```bash
sudo linux-maint status --verbose
sudo linux-maint logs 200
sudo linux-maint doctor
```

## 5) Automation (optional)

If you want machine-friendly output:

```bash
sudo linux-maint status --json
sudo linux-maint report --json
sudo linux-maint check --json
```
