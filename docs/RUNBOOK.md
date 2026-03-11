# Operator Runbook

Use this page for the normal daily operator loop after the toolkit is already set up.

If you are new to the project, start with [FIRST_5_MINUTES.md](FIRST_5_MINUTES.md) instead.

## Daily loop

```bash
linux-maint status
linux-maint report --short
linux-maint menu
```

Use this when you need the fastest human answer.

## When something looks wrong

```bash
linux-maint status --verbose
linux-maint diff
linux-maint doctor
linux-maint logs 200
```

If you prefer the menu:

1. `Overview`
2. `Triage`
3. `Share`

## When you want a fresh run

```bash
linux-maint check
linux-maint run --plan
linux-maint run
linux-maint status --verbose
```

## When you need escalation artifacts

```bash
linux-maint pack-logs --out /tmp
linux-maint export --json
linux-maint report --short
```

## When you need machine-readable output

```bash
linux-maint status --json
linux-maint report --json
linux-maint check --json
```

## Best companion docs

- [QUICK_REFERENCE.md](QUICK_REFERENCE.md)
- [troubleshooting.md](troubleshooting.md)
- [ARTIFACTS.md](ARTIFACTS.md)
- [REASONS.md](REASONS.md)
