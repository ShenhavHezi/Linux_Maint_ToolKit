# Troubleshooting

Use this page when a run looks wrong and you need the shortest path to a reliable answer.

For exact flag and schema details, use [reference.md](reference.md). For the everyday steady-state loop, use [RUNBOOK.md](RUNBOOK.md).

## Fast path

If you are under pressure, use this order:

1. `linux-maint status --verbose`
2. `linux-maint doctor`
3. `linux-maint diff`
4. `linux-maint pack-logs --out /tmp`

If you prefer the menu:

1. `linux-maint menu`
2. `Overview`
3. `Triage`
4. `Share`

## Before you start

- Examples below use `linux-maint ...`
- In installed mode, prepend `sudo` when the command needs root-owned config, logs, or state
- `<cfg_dir>` means your effective config root: repo-local fallback in repo mode, `/etc/linux_maint` in installed mode unless overridden
- Repo-mode artifacts normally live under `.logs/`

## Run and review (repo mode)

```bash
./bin/linux-maint run
./bin/linux-maint status
```

## Run and review (installed mode)

```bash
sudo linux-maint run
sudo linux-maint status
```

## Triage loop

### 1. Confirm the latest state

```bash
linux-maint status
linux-maint status --verbose
linux-maint status --reasons 5
```

Use this first to separate real failures from expected SKIPs and older noise.

### 2. Check what changed

```bash
linux-maint diff
linux-maint history --last 5 --table
```

Use this to answer:
- is this new
- is it getting worse
- did it start after a known change

### 3. Validate the environment

```bash
linux-maint doctor
linux-maint self-check
linux-maint deps
```

Use this when the problem may be local to the runner rather than the target host.

### 4. Decide whether to rerun

```bash
linux-maint check
linux-maint run --plan
linux-maint run
```

Rerun only after you understand whether you are dealing with:
- a real target issue
- missing optional config
- broken local prerequisites
- stale artifacts from an older run

## First-run expectations

On a new repo checkout or fresh install, `SKIP` is normal for monitors that need optional input files:

- `network_monitor` needs `<cfg_dir>/network_targets.txt`
- `cert_monitor` needs `<cfg_dir>/certs.txt`
- `ports_baseline_monitor` needs `<cfg_dir>/ports_baseline.txt`
- `config_drift_monitor` needs `<cfg_dir>/config_paths.txt`
- `user_monitor` needs `<cfg_dir>/baseline_users.txt` or `<cfg_dir>/baseline_sudoers.txt`
- `backup_check` needs `<cfg_dir>/backup_targets.csv`

Use:

```bash
linux-maint status --expected-skips
linux-maint doctor
```

## Common problem classes

### SSH or fleet access problems

Typical reasons:
- `ssh_unreachable`
- `collect_failed`

Check:

```bash
linux-maint doctor
linux-maint run --plan
```

Then verify host reachability, SSH keys, known-hosts policy, and any firewall or maintenance window rules.

### Missing config or baselines

Typical reasons:
- `config_missing`
- `baseline_missing`
- `missing_targets_file`

Check:

```bash
linux-maint config --diff-defaults
linux-maint doctor
```

Then populate the missing file under `<cfg_dir>` or allow the initial baseline path to complete.

### Service and package state problems

Typical reasons:
- `service_failed`
- `security_updates_pending`

Check:

```bash
linux-maint status --monitor service
linux-maint status --monitor patch
```

Then inspect the service manager or package workflow on the affected host.

### Artifact or local runner problems

Typical reasons:
- `summary_write_failed`
- `summary_checksum_failed`
- `early_exit`

Check:

```bash
linux-maint doctor
linux-maint self-check
linux-maint logs 200
```

Then confirm the active log/state directories are writable and not full.

## Narrowing the view

Use these filters to get to the useful slice quickly:

```bash
linux-maint status --host web --only WARN
linux-maint status --monitor service --reasons 5
linux-maint status --since 2h
linux-maint status --host '^web-[0-9]+$' --match-mode regex
linux-maint status --problems 100
```

When you need automation-safe output:

```bash
linux-maint status --json
linux-maint report --json
linux-maint export --json
```

## Escalation

When you need to hand the problem off, gather these together:

```bash
linux-maint version
linux-maint status --verbose
linux-maint report --short
linux-maint export --json
linux-maint pack-logs --out /tmp
```

Send:
- the bundle created by `pack-logs`
- `meta/support_handoff.txt` from the bundle
- the exact toolkit version
- whether the run happened in repo mode or installed mode

Use [ARTIFACTS.md](ARTIFACTS.md) for the bundle contents and release-verification side of that workflow.

## When to leave this page

- Use [REASONS.md](REASONS.md) when you need the meaning of a reason token
- Use [ARTIFACTS.md](ARTIFACTS.md) when you need bundle, export, or release artifact details
- Use [RUNBOOK.md](RUNBOOK.md) when the incident is over and you are back to the daily loop
