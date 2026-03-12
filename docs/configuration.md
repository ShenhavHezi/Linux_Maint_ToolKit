# Configuration

Use this page when you want to decide what to configure first, where the files live, and which settings matter early.

For exact variable-by-variable detail, use [reference.md](reference.md). For the shortest operator path, use [FIRST_5_MINUTES.md](FIRST_5_MINUTES.md).

## Start with the right scope

Most setups only need a few files at first.

### Minimum useful config

Touch these first:

- `servers.txt` for target hosts
- `services.txt` for service checks
- `network_targets.txt` if you want active reachability checks

If `network_targets.txt` is missing or empty, `network_monitor` will `SKIP` cleanly. That is normal on a first run.

### Add later when you need broader coverage

- `certs.txt`
- `backup_targets.csv`
- `config_paths.txt`
- `ports_baseline.txt`
- `baseline_users.txt`
- `baseline_sudoers.txt`

## Where config lives

### Installed mode

Default config root:

- `/etc/linux_maint`

This is the normal production path.

### Repo mode

Use repo mode when evaluating, developing, or running from a checkout.

- `LM_CFG_DIR=/path/to/config` overrides the config root directly
- if `/etc/linux_maint` is not writable, the wrapper can fall back to a repo-local config root and export `LM_CFG_DIR` for monitors automatically

Templates live under:

- `etc/linux_maint/*.example`
- `etc/linux_maint/README.md`

## First configuration decisions

### 1. Local-only or SSH fleet

For local-only checks, keep the inventory simple and prefer:

```bash
LM_LOCAL_ONLY=true
```

For fleet mode, populate:

- `servers.txt`
- optional `excluded.txt`
- optional `hosts.d/`
- optional `inventory_meta.csv` if you want run-time filters by tag, role, or environment

`inventory_meta.csv` uses:

- `host,tags,role,env`
- tags separated by `;` or `|`

Example:

```csv
host,tags,role,env
web-01,web;frontend,web,prod
db-01,db;stateful,db,prod
lab-01,lab;canary,web,dev
```

You can then scope plans and runs with:

```bash
linux-maint run --tag web --env prod --plan --json
linux-maint run --role db --plan --json
```

### 2. Conservative or broad coverage

If you are in a dark-site or tightly controlled environment:

- leave optional files absent until you want those checks
- consider `LM_DARK_SITE=true`
- keep `network_targets.txt` empty until you have internal targets worth probing

### 3. Fast fail or tolerant runtime

Early runtime controls worth knowing:

- `MONITOR_TIMEOUT_SECS`
- `MONITOR_TIMEOUTS_FILE`
- `MONITOR_RUNTIME_WARN_FILE`
- `LM_MAX_PARALLEL`
- `LM_MAX_PARALLEL_CAP`

## Common knobs worth caring about

These are the settings most operators actually need early:

- `LM_CFG_DIR=/path`
- `LM_LOCAL_ONLY=true`
- `LM_DARK_SITE=true`
- `LM_NOTIFY=0|1`
- `LM_SSH_OPTS="..."`
- `LM_SSH_ALLOWLIST="..."`
- `MONITOR_TIMEOUT_SECS=600`
- `MONITOR_TIMEOUTS_FILE=<cfg_dir>/monitor_timeouts.conf`
- `MONITOR_RUNTIME_WARN_FILE=<cfg_dir>/monitor_runtime_warn.conf`

These are useful later, not first:

- `LM_TREND_CACHE=1`
- `LM_TREND_CACHE_TTL=60`
- `LM_INVENTORY_CACHE=1`
- `LM_INVENTORY_CACHE_TTL=3600`
- `LM_NOTIFY_CONNECT_TIMEOUT=5`
- `LM_NOTIFY_MAX_TIME=15`
- `LM_TICKET_CONNECT_TIMEOUT=5`
- `LM_TICKET_MAX_TIME=15`

## SSH allowlist

If you want to restrict remote commands, set `LM_SSH_ALLOWLIST` in your main config file.

Example:

```bash
LM_SSH_ALLOWLIST='^bash -lc |^command -v |^df |^ss |^netstat |^systemctl |^ping |^nc |^curl |^timeout |^chronyc |^ntpq |^timedatectl |^mountpoint |^stat |^uname '
```

Start broad, then tighten based on blocked-command warnings.

## A safe first configuration loop

Use this order:

```bash
linux-maint init --minimal
linux-maint check
linux-maint run --plan
linux-maint run
linux-maint status --expected-skips
linux-maint baseline status
```

Then add optional files one by one instead of trying to configure every monitor at once.

## When to leave this page

- Use [installation.md](installation.md) when you are deciding how to deploy
- Use [OPERATIONS.md](OPERATIONS.md) for fleet and deployment workflows
- Use [reference.md](reference.md) for the full config and environment reference
