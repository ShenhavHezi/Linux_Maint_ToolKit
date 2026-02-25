# FAQ

## Why do I see SKIP statuses?
Most SKIPs mean optional config files are missing (for example `network_targets.txt` or `certs.txt`). Use:

```bash
linux-maint status --expected-skips
```

Then populate the missing files or treat them as expected for your environment.

## What does `reason=ssh_unreachable` mean?
The runner could not SSH to the target host. Check DNS, firewall rules, keys, and `LM_SSH_OPTS`.

## What does `reason=config_missing` mean?
A required config file is missing. Run `sudo linux-maint init` and populate the missing file.

## What does `reason=baseline_missing` mean?
A baseline file hasn’t been created yet. Generate it with:

```bash
linux-maint baseline ports --update
linux-maint baseline configs --update
linux-maint baseline users --update
linux-maint baseline sudoers --update
```

## How do I run only specific monitors?
Use `--only` or `--skip`:

```bash
linux-maint run --only service_monitor,ntp_drift_monitor
linux-maint run --skip inventory_export,backup_check
```

## How do I preview a run without executing it?
Use `--plan`:

```bash
linux-maint run --plan
linux-maint run --plan --json
```

## How do I produce machine-readable outputs safely?
Use `--json` and optional redaction:

```bash
LM_REDACT_JSON=1 linux-maint report --json
LM_REDACT_JSON_STRICT=1 linux-maint report --json
```

## How do I verify a release tarball?
Use the built-in verify helper:

```bash
linux-maint verify-release Linux_Maint_ToolKit-*.tgz --sums SHA256SUMS
```
