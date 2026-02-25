# Linux Maintenance Toolkit Reference

This document contains the detailed reference sections moved out of the main README.


## Optional packages for full coverage (recommended on bare metal)

Some monitors provide best results when these tools are installed:
- `storage_health_monitor.sh`: `smartctl` (smartmontools) and `nvme` (nvme-cli)


### Vendor RAID controller tooling (optional)

On some bare-metal servers, SMART data is hidden behind a hardware RAID controller.
If you want controller-level health (virtual disk state, predictive failures, rebuilds), install the appropriate vendor CLI.
`storage_health_monitor.sh` will auto-detect and use these tools when available:

- `storcli` / `perccli` (Broadcom/LSI MegaRAID family)
- `ssacli` (HPE Smart Array)
- `omreport` (Dell OMSA)

If none are installed, the monitor reports controller status as `ctrl=NA()` and continues with mdraid/SMART/NVMe checks.

Install examples:

### RHEL / CentOS / Rocky / Alma / Fedora
```bash
sudo dnf install -y smartmontools nvme-cli
```

### Debian / Ubuntu
```bash
sudo apt-get update
sudo apt-get install -y smartmontools nvme-cli
```

### SUSE / openSUSE
```bash
sudo zypper install -y smartmontools nvme-cli
```

## Monitor reference (what checks what)

| Script | Purpose | Config file (if any) | Typical WARN/CRIT causes |
|---|---|---|---|
| `health_monitor.sh` | CPU/mem/load/disk/top snapshot | none | low disk, load spikes, memory pressure |
| `filesystem_readonly_monitor.sh` | detect read-only mounts | none (optional excludes via env) | filesystems remounted read-only |
| `inode_monitor.sh` | inode utilization thresholds | `/etc/linux_maint/inode_thresholds.txt` (optional excludes) | inode exhaustion |
| `network_monitor.sh` | ping/tcp/http checks | `/etc/linux_maint/network_targets.txt` | packet loss, TCP connect fail, HTTP latency/status |
| `service_monitor.sh` | service health (systemd) | `/etc/linux_maint/services.txt` | inactive/failed services |
| `timer_monitor.sh` | linux-maint timer health (systemd) | none (systemd required) | timer missing/disabled/inactive |
| `last_run_age_monitor.sh` | wrapper last-run freshness | none (optional threshold/log dir) | missing/stale wrapper logs |
| `ntp_drift_monitor.sh` | time sync health | none | unsynced clock, high offset |
| `patch_monitor.sh` | pending updates/reboot hints | none | security updates pending, reboot required |
| `storage_health_monitor.sh` | RAID/SMART/NVMe storage health | none (best-effort) | degraded RAID, SMART failures, NVMe critical warnings |
| `kernel_events_monitor.sh` | kernel log scan (OOM/I/O/FS/hung tasks) | none (journalctl recommended) | OOM killer events, disk I/O errors, filesystem errors |
| `cert_monitor.sh` | certificate expiry | `/etc/linux_maint/certs.txt` | expiring/expired certs, verify failures |
| `nfs_mount_monitor.sh` | NFS mounted + responsive | none | stale/unresponsive mounts |
| `ports_baseline_monitor.sh` | port drift vs baseline | `/etc/linux_maint/ports_baseline.txt` | new/removed listening ports |
| `config_drift_monitor.sh` | config drift vs baseline | `/etc/linux_maint/config_paths.txt` | changed hashes vs baseline |
| `user_monitor.sh` | user/sudoers drift + SSH failures | `/etc/linux_maint/baseline_users.txt`, `/etc/linux_maint/baseline_sudoers.txt` | new users, sudoers changed, brute-force attempts |
| `backup_check.sh` | backup freshness/integrity | `/etc/linux_maint/backup_targets.csv` | old/missing/small/corrupt backups |
| `inventory_export.sh` | HW/SW inventory CSV | none | collection failures |

## What to check next (quick hints)

- `network_monitor.sh`: verify `/etc/linux_maint/network_targets.txt`, test DNS/connectivity from the runner, and check firewall rules.
- `service_monitor.sh`: confirm the unit name in `services.txt`, check `systemctl status <unit>`, and review recent journal entries.
- `timer_monitor.sh`: check `systemctl status linux-maint.timer` and ensure it is enabled and active.
- `filesystem_readonly_monitor.sh`: check `dmesg`/`journalctl -k` for I/O errors, review storage health, and remount only after root cause is addressed.
- `last_run_age_monitor.sh`: confirm the wrapper/timer runs on schedule and that `/var/log/health` is writable.
- `patch_monitor.sh`: run your distro’s update command to confirm pending updates and check reboot flags.
- `ntp_drift_monitor.sh`: ensure chrony/timesyncd is running and reachable; check `chronyc tracking` or `timedatectl`.
- `config_drift_monitor.sh`: validate baseline files exist and compare the reported path with your change history.



### Keeping README defaults in sync

If you change default thresholds/paths inside scripts, regenerate the **Tuning knobs** section before committing:

```bash
python3 tools/update_readme_defaults.py
```

## Tuning knobs (common configuration variables)

### Wrapper-level notification (single summary email per run)

Notifications can optionally include a `DIFF_SINCE_LAST_RUN` section (new failures, recovered, still failing) computed from the summary artifacts.


By default, the wrapper does **not** send email. You can enable a single per-run summary email using either environment variables or `/etc/linux_maint/notify.conf`.

Supported settings:
- `LM_NOTIFY` = `0|1` (default: `0`)
- `LM_NOTIFY_TO` = `"user@company.com,ops@company.com"` (required when enabled; comma/space separated)
- `LM_NOTIFY_ONLY_ON_CHANGE` = `0|1` (default: `0`)
- `LM_NOTIFY_SUBJECT_PREFIX` = `"[linux_maint]"`
- `LM_NOTIFY_STATE_DIR` = `"/var/lib/linux_maint"` (where the last-run hash is stored; falls back to `LM_STATE_DIR`)
- `LM_NOTIFY_FROM` = `"linux_maint@<host>"` (used when `sendmail` is the transport)

Example `/etc/linux_maint/notify.conf`:

```bash
LM_NOTIFY=1
LM_NOTIFY_TO="ops@company.com"
LM_NOTIFY_ONLY_ON_CHANGE=1
LM_NOTIFY_SUBJECT_PREFIX="[linux_maint]"
```

Mail transport auto-detection:
- uses `mail` if available
- otherwise uses `sendmail`

Dark-site wrapper profile:
- `LM_DARK_SITE=true` enables conservative wrapper defaults without breaking explicit overrides:
  - `LM_LOCAL_ONLY=true`
  - `LM_NOTIFY_ONLY_ON_CHANGE=1`
  - `MONITOR_TIMEOUT_SECS=300` (instead of the regular wrapper default `600`)
  - Run `sudo linux-maint tune dark-site` to write these defaults into `linux-maint.conf` without overwriting existing values.


Most defaults below are taken directly from the scripts (current repository version).

### Timeout policy

Timeout protection exists at two layers:
- Wrapper-level timeout: `MONITOR_TIMEOUT_SECS` (default `600`, dark-site profile default `300`) limits each monitor script runtime.
- Optional per-monitor wrapper overrides: `MONITOR_TIMEOUTS_FILE` (default `${LM_CFG_DIR:-/etc/linux_maint}/monitor_timeouts.conf`) with lines like `disk_trend_monitor=60`.

Monitor-specific bounded operations should still use local command timeouts where applicable.
Example: `nfs_mount_monitor` uses `NFS_STAT_TIMEOUT` (default `5s`) for per-mount responsiveness probes.

### Temp directory selection

Several scripts create temporary files (wrapper, monitors, tools).

- `TMPDIR` (if set) is used as the primary temp location.
- If unwritable, the code falls back to `/var/tmp` then `/tmp` (best-effort).
- Some monitors also consider `LM_STATE_DIR` for temp files when appropriate.

### Runtime summary (wrapper logs)

The wrapper records per-monitor runtime in milliseconds and includes:

- `RUNTIME monitor=<name> ms=<duration>` lines in the wrapper log
- A “Top runtimes (ms)” section in the human summary
- Optional per-step timings may be emitted by monitors using `lm_time`:
  - `RUNTIME_STEP monitor=<name> step=<label> ms=<duration> rc=<rc>`

You can extract recent runtimes with:

```bash
linux-maint runtimes
linux-maint runtimes --last 3 --json
```

When `MONITOR_RUNTIME_WARN_FILE` is present, `linux-maint runtimes` highlights monitors that exceed their thresholds (colorized when color is enabled).

JSON output includes `unit=ms` and a `source_file` path for each row.
Schema:
- `docs/schemas/runtimes.json` — JSON schema for `linux-maint runtimes --json`.

### Runtime warn thresholds

You can optionally warn on slow monitors by creating a runtime warn file:

- `MONITOR_RUNTIME_WARN_FILE` = `${LM_CFG_DIR:-/etc/linux_maint}/monitor_runtime_warn.conf`
- Format: `monitor_name=seconds` (one per line, comments allowed)

When a monitor runtime exceeds its threshold, the wrapper emits:

```
monitor=runtime_guard host=runner status=WARN reason=runtime_exceeded target_monitor=<name> runtime_ms=<ms> threshold_ms=<ms>
```

### `inode_monitor.sh`
- `THRESHOLDS` = `"/etc/linux_maint/inode_thresholds.txt"   # CSV: mountpoint,warn%,crit% (supports '*' default)`
- `EXCLUDE_MOUNTS` = `"/etc/linux_maint/inode_exclude.txt"  # Optional: list of mountpoints to skip`
- `DEFAULT_WARN` = `80`
- `DEFAULT_CRIT` = `95`
- `EXCLUDE_FSTYPES_RE` = `'^(tmpfs|devtmpfs|overlay|squashfs|proc|sysfs|cgroup2?|debugfs|rpc_pipefs|autofs|devpts|mqueue|hugetlbfs|fuse\..*|binfmt_misc|pstore|nsfs)$'`

### `filesystem_readonly_monitor.sh`
- `LM_MOUNTS_FILE` = `"/proc/mounts"  # Alternate mounts file (tests/offline)`
- `LM_FS_RO_EXCLUDE_RE` = `'^(proc|sysfs|devtmpfs|tmpfs|devpts|cgroup2?|cgroup|debugfs|tracefs|mqueue|hugetlbfs|pstore|squashfs|overlay|rpc_pipefs|autofs|fuse\..*|binfmt_misc|securityfs|efivarfs|configfs|bpf|fusectl)$'`
- `LM_FS_RO_EXCLUDE_MOUNTS_RE` = `'^/(boot|boot/efi|usr|etc)$'  # Optional mountpoint excludes`

### `network_monitor.sh`
- `TARGETS` = `"/etc/linux_maint/network_targets.txt"   # CSV: host,check,target,key=val,...`
- `PING_COUNT` = `3`
- `PING_TIMEOUT` = `3`
- `PING_LOSS_WARN` = `20`
- `PING_LOSS_CRIT` = `50`
- `PING_RTT_WARN_MS` = `150`
- `PING_RTT_CRIT_MS` = `500`
- `TCP_TIMEOUT` = `3`
- `TCP_LAT_WARN_MS` = `300`
- `TCP_LAT_CRIT_MS` = `1000`
- `HTTP_TIMEOUT` = `5`
- `HTTP_LAT_WARN_MS` = `800`
- `HTTP_LAT_CRIT_MS` = `2000`
- `HTTP_EXPECT` = `""   # default: 200–399 when empty`

### `service_monitor.sh`
- `SERVICES` = `"/etc/linux_maint/services.txt"     # One service per line (unit name). Comments (#…) and blanks allowed.`
- `AUTO_RESTART` = `"false"                          # "true" to attempt restart on failure (requires root or sudo NOPASSWD)`
- `EMAIL_ON_ALERT` = `"false"                        # "true" to email when any service is not active`

### `last_run_age_monitor.sh`
- `LM_LAST_RUN_MAX_AGE_MIN` = `120  # Warn if wrapper log is older than this`
- `LM_LAST_RUN_LOG_DIR` = `"/var/log/health"  # Where wrapper logs live`

### `ports_baseline_monitor.sh`
- `BASELINE_DIR` = `"/etc/linux_maint/baselines/ports"       # Per-host baselines live here`
- `ALLOWLIST_FILE` = `"/etc/linux_maint/ports_allowlist.txt"  # Optional allowlist`
- `AUTO_BASELINE_INIT` = `"true"       # If no baseline for a host, create it from current snapshot`
- `BASELINE_UPDATE` = `"false"         # If true, replace baseline with current snapshot after reporting`
- `INCLUDE_PROCESS` = `"true"          # Include process names in baseline when available`
- `EMAIL_ON_CHANGE` = `"true"          # Send email when NEW/REMOVED entries are detected`

### `config_drift_monitor.sh`
- `CONFIG_PATHS` = `"/etc/linux_maint/config_paths.txt"        # Targets (files/dirs/globs)`
- `ALLOWLIST_FILE` = `"/etc/linux_maint/config_allowlist.txt"  # Optional: paths to ignore (exact or substring)`
- `BASELINE_DIR` = `"/etc/linux_maint/baselines/configs"       # Per-host baselines live here`
- `AUTO_BASELINE_INIT` = `"true"   # If baseline missing for a host, create it from current snapshot`
- `BASELINE_UPDATE` = `"false"     # After reporting, accept current as new baseline`
- `EMAIL_ON_DRIFT` = `"true"       # Send email when drift detected`

### `user_monitor.sh`
- `USERS_BASELINE_DIR` = `"/etc/linux_maint/baselines/users"       # per-host: ${host}.users`
- `SUDO_BASELINE_DIR` = `"/etc/linux_maint/baselines/sudoers"      # per-host: ${host}.sudoers`
- `AUTO_BASELINE_INIT` = `"true"    # create baseline on first run`
- `BASELINE_UPDATE` = `"false"      # update baseline to current after reporting`
- `EMAIL_ON_ALERT` = `"true"        # send email if anomalies are detected`
- `USER_MIN_UID` = `0`
- `FAILED_WINDOW_HOURS` = `24`
- `FAILED_WARN` = `10`
- `FAILED_CRIT` = `50`

### `backup_check.sh`
- `TARGETS` = `"/etc/linux_maint/backup_targets.csv"  # CSV: host,pattern,min_size_mb,max_age_hours,verify`

### `cert_monitor.sh`
- `THRESHOLD_WARN_DAYS` = `30`
- `THRESHOLD_CRIT_DAYS` = `7`
- `TIMEOUT_SECS` = `10`
- `EMAIL_ON_WARN` = `"true"`

### `storage_health_monitor.sh`
- `SMARTCTL_TIMEOUT_SECS` = `10`
- `MAX_SMART_DEVICES` = `32`
- `RAID_TOOL_TIMEOUT_SECS` = `12`
- `EMAIL_ON_ISSUE` = `"true"`

### `kernel_events_monitor.sh`
- `KERNEL_WINDOW_HOURS` = `24`
- `WARN_COUNT` = `1`
- `CRIT_COUNT` = `5`
- `PATTERNS` = `'oom-killer|out of memory|killed process|soft lockup|hard lockup|hung task|blocked for more than|I/O error|blk_update_request|Buffer I/O error|EXT4-fs error|XFS \(|btrfs: error|nvme.*timeout|resetting link|ata[0-9].*failed|mce:|machine check'`
- `EMAIL_ON_ALERT` = `"true"`

### `preflight_check.sh`
- `REQ_CMDS` = `(bash awk sed grep df ssh)`
- `OPT_CMDS` = `(openssl ss netstat journalctl smartctl nvme mail timeout)`
- `LM_PREFLIGHT_OPT_CMDS` = `"openssl ss netstat journalctl smartctl nvme timeout"  # Optional override (space-separated)`
- If `LM_EMAIL_ENABLED=false` and `LM_NOTIFY=0`, `mail` is ignored in optional checks.

### `disk_trend_monitor.sh`
- `STATE_BASE` = `""` (optional override; state path precedence is: explicit `STATE_BASE` → `${LM_STATE_DIR}/linux_maint/disk_trend` when `LM_STATE_DIR` is set → `/var/lib/linux_maint/disk_trend`)
- `WARN_DAYS` = `14`
- `CRIT_DAYS` = `7`
- `HARD_WARN_PCT` = `90`
- `HARD_CRIT_PCT` = `95`
- `MIN_POINTS` = `2`
- `LM_DISK_TREND_INODES` = `0` (set to `1|true` to collect inode trend state and include inode rollup counters in summary output)
- `EXCLUDE_FSTYPES_RE` = `'^(tmpfs|devtmpfs|overlay|squashfs|proc|sysfs|cgroup2?|debugfs|rpc_pipefs|autofs|devpts|mqueue|hugetlbfs|fuse\..*|binfmt_misc|pstore|nsfs)$'`
- `EXCLUDE_MOUNTS_FILE` = `"/etc/linux_maint/disk_trend_exclude_mounts.txt"`
- If the resolved state path is not writable, monitor falls back to `/tmp/linux_maint/disk_trend` and logs a warning.

When `LM_DISK_TREND_INODES=1|true`, `disk_trend_monitor` also emits compact inode rollup summary keys:
- `inode_mounts=<count>`
- `inode_warn=<count>`
- `inode_crit=<count>`

### `nfs_mount_monitor.sh`
- `NFS_STAT_TIMEOUT` = `5`
- `EMAIL_ON_ISSUE` = `"true"`

### `inventory_export.sh`
- `OUTPUT_DIR` = `"/var/log/inventory"`
- `DETAILS_DIR` = `"${OUTPUT_DIR}/details"`
- `LM_INVENTORY_CACHE` = `0` (set to `1` to reuse recent inventory data)
- `LM_INVENTORY_CACHE_TTL` = `3600` (seconds)
- `LM_INVENTORY_CACHE_DIR` = `"${OUTPUT_DIR}/cache"`
- `LM_INVENTORY_CACHE_MAX` = `0` (max cached entries to retain; `0` = unlimited)
- `MAIL_ON_RUN` = `"false"`


## Output contract (machine-parseable summary lines)

Most monitors emit one or more standardized *summary lines* using `lm_summary()` (from `lib/linux_maint.sh`).
The wrapper (`run_full_health_monitor.sh`) also extracts these lines into a summary-only artifact.

### Summary line format

Each summary line is a single line of space-separated `key=value` pairs. The first keys are always:

```text
monitor=<monitor_name> host=<target> status=<OK|WARN|CRIT|UNKNOWN|SKIP> node=<runner_fqdn> [key=value ...]
```

Notes:
- `monitor` is the script/monitor logical name (e.g. `patch_monitor`).
- `host` is the target host being evaluated. For fleet/global summaries some monitors use `host=all`.
- `status` is the logical result (see below).
- `node` is the machine that executed the monitor (runner).
- Additional keys are monitor-specific metrics (counts, thresholds, paths, etc.).
- Optional `next_step=<token>` may be emitted for common `reason=` values to suggest a remediation.
- Each monitor must emit **exactly one** summary line per target host per run.
- Summary lines are the only content allowed on stdout for monitor scripts; any progress or detail output must go to stderr.

### Status values (semantic meaning)

- `OK`: check succeeded; no action required.
- `WARN`: potential issue / attention suggested; not necessarily an outage.
- `CRIT`: actionable failure / immediate attention required.
- `UNKNOWN`: the check could not be completed reliably (tool missing, permission issue, unexpected error).
- `SKIP`: the check intentionally did not evaluate (missing optional config/baseline, unsupported environment).

### `reason=` key (recommended on non-OK paths)

For non-`OK` outcomes, monitors should emit a `reason=<token>` key when possible.
This makes automation and triage much easier than relying on free-form logs.

Common `reason` values used in this project:
- `ssh_unreachable`
- `collect_failed`
- `kernel_log_unreadable`
- `missing_targets_file`
- `unsupported_pkg_mgr`
- `baseline_missing`
- `baseline_created`
- `no_timesync_tool`
- `early_exit`

### Summary lint guardrails (length + key budget)

The test suite enforces summary readability and parser safety with explicit budgets:

- `tests/summary_noise_lint.sh`
  - Global line-length budget via `LM_SUMMARY_MAX_LEN` (default `220`).
  - Optional per-monitor overrides via `LM_SUMMARY_MONITOR_MAX_LEN_MAP` (example: `inventory_export=260,disk_trend_monitor=240`).
- `tests/summary_parse_safety_lint.py`
  - Global key-count budget via `LM_SUMMARY_MAX_KEYS` (default `18`).
  - Optional per-monitor overrides via `LM_SUMMARY_MONITOR_MAX_KEYS_MAP` (example: `inventory_export=24`).

Keep overrides explicit and minimal so growth is intentional and reviewed.

### Artifacts written by the wrapper

When running the full wrapper (`run_full_health_monitor.sh`) in installed mode:
- Full log: `/var/log/health/full_health_monitor_<timestamp>.log` and `..._latest.log` symlink
- Summary-only file (only `monitor=` lines, no timestamps): `/var/log/health/full_health_monitor_summary_<timestamp>.log` and `full_health_monitor_summary_latest.log` symlink

These artifacts are designed to be consumed by automation/CI or log shipping tools.

### CLI output conventions (human-facing)

- Section headers use `=== Section ===` for quick scanning.
- Color is enabled only when output is a TTY and `NO_COLOR` is not set.
- You can force color for non-TTY contexts with `LM_FORCE_COLOR=1`.
- `NO_COLOR=1` (or `LM_NO_COLOR=1`) always disables color, even if force color is set.
- Non-JSON outputs may colorize non-zero status counts (for example in `status --last` and `history`).
- Progress bars (when enabled) render on stderr only and never affect JSON output.
- Human-facing diagnostics should go to stderr so stdout remains machine-clean.

## Exit codes (for automation)

### tests/smoke.sh exit codes

The repo smoke test (used by CI and for quick dark-site validation) uses stable exit codes:

- `0`: smoke ok
- `3`: smoke ok, but optional checks were skipped (typically sudo-gated tests)

Any other non-zero indicates a hard failure in a required smoke sub-test.

The wrapper prints a final `SUMMARY_RESULT` line that includes counters: `ok`, `warn`, `crit`, `unknown`, and `skipped` (for monitors skipped due to missing config gates).

All scripts aim to follow:
- `0` = OK
- `1` = WARN
- `2` = CRIT
- `3` = UNKNOWN/ERROR

The wrapper returns the **worst** exit code across all executed monitors.


## Installed file layout (recommended)

Default `PREFIX` is `/usr/local` (override with `PREFIX=/custom` during install).

Core binaries:
- `/usr/local/bin/linux-maint` (CLI)
- `/usr/local/sbin/run_full_health_monitor.sh` (wrapper)

Libraries and monitors:
- `/usr/local/lib/linux_maint.sh`
- `/usr/local/lib/linux_maint_conf.sh`
- `/usr/local/libexec/linux_maint/*.sh` (monitors)
- `/usr/local/libexec/linux_maint/summary_diff.py`
- `/usr/local/libexec/linux_maint/pack_logs.sh`
- `/usr/local/libexec/linux_maint/seed_known_hosts.sh`

Config and templates:
- `/etc/linux_maint/linux-maint.conf`
- `/etc/linux_maint/conf.d/*.conf`
- `/etc/linux_maint/{servers.txt,services.txt,excluded.txt,network_targets.txt}`
- `/etc/linux_maint/monitor_timeouts.conf` (optional)
- `/etc/linux_maint/monitor_runtime_warn.conf` (optional)
- `/etc/linux_maint/baselines/` (baseline data)
- `/usr/local/share/linux_maint/templates/` (template copy for `linux-maint init`)

Logs and state:
- `/var/log/health/` (wrapper logs + summaries)
- `/var/lib/linux_maint/` (state, summary diff)
- `/var/lock/` (locks)

Operator docs:
- `/usr/local/share/Linux_Maint_ToolKit/docs/`

## CLI usage (`linux-maint`) (appendix)

After installation, use the `linux-maint` CLI as the primary interface.



### Commands



- `linux-maint run` *(root required)*: run the full wrapper (`run_full_health_monitor.sh`).
  - `--progress|--no-progress`: enable/disable the run progress bar (overrides `LM_PROGRESS`).
  - `--only a,b`: run only selected monitors (names with or without `_monitor`).
  - `--skip a,b`: skip selected monitors.
  - `--strict`: fail the run if any monitor emits malformed summary lines (adds `reason=summary_invalid`).

- `linux-maint init [--minimal] [--force]` *(root required)*: install `/etc/linux_maint` templates from the repo checkout.
  - By default, existing files are not overwritten.
  - `--force` overwrites existing files.

- `linux-maint explain monitor <name>`: show monitor purpose, deps, and common `reason=` tokens.

- `linux-maint status` *(root required)*: show last run metadata plus a compact, severity-sorted problems summary by default. Use `--verbose` for raw summary lines.
- `linux-maint check` *(root required)*: run config validation + preflight and show a short OK/WARN/CRIT summary.
  - `--json`: emit machine-friendly summary and expected SKIPs.

Status flags (installed mode):

- `--verbose` — show raw summary lines
- `--problems N` — number of problem entries to display (default 20, max 100)
- `--reasons N` — optional top-N reason rollup section for non-OK lines (default 0=hidden, max 20)
- `--only OK|WARN|CRIT|UNKNOWN|SKIP` — filter by status
- `--host PATTERN` — show only entries where `host` contains `PATTERN`
- `--monitor PATTERN` — show only entries where `monitor` contains `PATTERN`
- `--match-mode contains|exact|regex` — how `--host`/`--monitor` are matched (default: `contains`)
- `--since <int><s|m|h|d>` — include only timestamped summary artifacts from the recent time window (e.g., `30s`, `15m`, `2h`, `1d`)
- `--expected-skips` — print a short list of expected SKIPs based on missing optional config (not compatible with `--json`)
- `--group-by host|monitor|reason` — group summary lines with stable ordering (reason grouping includes non-OK entries)
- `--top N` — cap the number of group-by rows (requires `--group-by`)
- `--prom` — emit Prometheus textfile-style summary metrics to stdout (overall + per-status counts)

- `linux-maint report` *(root required)*: show combined status + trends + runtimes.
  - `--short` emits a one-screen summary with totals, top problems, and next steps.
  - `--redact` applies best-effort redaction to human output only (not JSON).

Note: when optional config/baselines are missing, `status`/`report` show an `Expected SKIPs` banner by default (suppressed in compact/summary output). Use `--expected-skips` for the explicit list.

- `linux-maint metrics --json` *(root required)*: emit a single JSON snapshot with status + trends + runtimes for automation.
- `linux-maint run-index` *(root required)*: show stats for `run_index.jsonl` and optionally prune with `--keep N`.


### `linux-maint status --json` compatibility contract

`linux-maint status --json` is intended for automation use and keeps a stable top-level shape.

Top-level keys:
- `status_json_contract_version` (integer, current value: `1`)
- `mode` (string: `repo` or `installed`)
- `last_status` (object; parsed from `last_status_full` key/value file)
- `summary_file` (string path when present, `null` when no summary is available)
- `totals` (object with integer keys: `CRIT`, `WARN`, `UNKNOWN`, `SKIP`, `OK`)
- `problems` (array of objects; severity-sorted, bounded by `--problems`)
- `runtime_warnings` (array of objects; entries from `runtime_guard` monitor lines, includes `target_monitor` and runtime details)
- `reason_rollup` (optional array; present only when `--reasons N` is requested)

Compatibility policy:
- Existing keys/types above are treated as stable for contract version `1`.
- Additive keys may be introduced without breaking compatibility.
- Breaking shape/type changes require incrementing `status_json_contract_version`.

Schemas:
- `docs/schemas/status.json` — JSON schema for `linux-maint status --json`.

### `linux-maint report --json` compatibility contract

Top-level keys:
- `report_json_contract_version` (integer, current value: `1`)
- `status` (object; same payload as `linux-maint status --json`)
- `trend` (object; same payload as `linux-maint trend --json`)
- `runtimes` (object; same payload as `linux-maint runtimes --json`)

Compatibility policy:
- Existing keys/types above are treated as stable for contract version `1`.
- Additive keys may be introduced without breaking compatibility.
- Breaking shape/type changes require incrementing `report_json_contract_version`.

Schema:
- `docs/schemas/report.json` — JSON schema for `linux-maint report --json`.

### `linux-maint metrics --json` compatibility contract

Top-level keys:
- `metrics_json_contract_version` (integer, current value: `1`)
- `status` (object; same payload as `linux-maint status --json`)
- `trend` (object; same payload as `linux-maint trend --json`)
- `runtimes` (object; same payload as `linux-maint runtimes --json`)
- `severity_totals` (object; counts of `monitor=` lines by status)
- `host_counts` (object; worst-status-per-host counts derived from summary lines)
- `monitor_durations_ms` (object; map of `monitor` to runtime in ms)

Schema:
- `docs/schemas/metrics.json` — JSON schema for `linux-maint metrics --json`.

### `linux-maint diff --json` compatibility contract

Top-level keys:
- `new_failures` (array; non-OK transitions from `OK` to `WARN|CRIT|UNKNOWN`)
- `recovered` (array; transitions from non-OK to `OK`)
- `still_bad` (array; entries that remain non-OK)
- `changed` (array; other transitions, including new rows)

Schema:
- `docs/schemas/diff.json` — JSON schema for `linux-maint diff --json`.

### `linux-maint self-check --json` compatibility contract

Top-level keys:
- `mode` (string: `repo` or `installed`)
- `cfg_dir` (string path to config root)
- `config` (object; `dir_exists` plus per-file existence)
- `paths` (array; log/state/lock paths with `exists`/`writable`)
- `dependencies` (array; required/optional commands and presence)

Schema:
- `docs/schemas/self_check.json` — JSON schema for `linux-maint self-check --json`.

### `linux-maint history --json` compatibility contract

Top-level keys:
- `history_json_contract_version` (integer, current value: `1`)
- `runs` (array of run index entries; newest first)

Compatibility policy:
- Existing keys/types above are treated as stable for contract version `1`.
- Additive keys may be introduced without breaking compatibility.
- Breaking shape/type changes require incrementing a contract version and schema update.

Schemas:
- `docs/schemas/history.json` — JSON schema for `linux-maint history --json`.
- `docs/schemas/run_index.json` — JSON schema for each `run_index.jsonl` entry.

### `linux-maint config --json` compatibility contract

Top-level keys:
- `config_json_contract_version` (integer, current value: `1`)
- `cfg_dir` (string path to the config root)
- `sources` (array of config file paths used to build the effective config)
- `values` (object; effective config key/value pairs as strings)

Compatibility policy:
- Existing keys/types above are treated as stable for contract version `1`.
- Additive keys may be introduced without breaking compatibility.
- Breaking shape/type changes require incrementing `config_json_contract_version`.

Schema:
- `docs/schemas/config.json` — JSON schema for `linux-maint config --json`.

Example (`status --json`):

```json
{
  "mode": "installed",
  "status_json_contract_version": 1,
  "summary_file": "/var/log/health/full_health_monitor_summary_latest.log",
  "totals": { "CRIT": 0, "WARN": 1, "UNKNOWN": 0, "SKIP": 2, "OK": 14 },
  "problems": [
    { "status": "WARN", "monitor": "patch_monitor", "host": "server-a", "reason": "security_updates_pending" }
  ],
  "runtime_warnings": []
}
```

### `linux-maint doctor --json` keys

Top-level keys:
- `mode` (string: `repo` or `installed`)
- `cfg_dir` (string path)
- `config` (object with `dir_exists`, `files`, `hosts_configured`)
- `monitor_gates` (array of monitor gate entries and their `present` status)
- `dependencies` (array of command availability with package hints)
- `writable_locations` (array of path checks: `exists`, `writable`)
- `fix_suggestions` (array of suggested remediation actions)
- `fix_actions` (array of structured actions taken by `doctor --fix`; empty when no fixes attempted)
- `next_actions` (array of recommended follow-up commands)

Schema:
- `docs/schemas/doctor.json` — JSON schema for `linux-maint doctor --json`.

Example (`doctor --json`):

```json
{
  "mode": "installed",
  "cfg_dir": "/etc/linux_maint",
  "config": { "dir_exists": true, "hosts_configured": 3, "files": { "servers.txt": true } },
  "monitor_gates": [
    { "monitor": "network_monitor", "path": "/etc/linux_maint/network_targets.txt", "present": false }
  ],
  "dependencies": [
    { "cmd": "curl", "present": true, "hint": "curl" }
  ],
  "writable_locations": [
    { "path": "/var/log/health", "exists": true, "writable": true }
  ],
  "fix_suggestions": [
    "Add network targets to /etc/linux_maint/network_targets.txt"
  ],
  "fix_actions": [
    { "id": 1, "action": "create_dir", "target": "/var/log/health", "status": "ok" }
  ],
  "next_actions": [
    "linux-maint verify-install",
    "sudo linux-maint init"
  ]
}
```



- `linux-maint trend [--last N] [--since DATE] [--until DATE] [--json|--csv|--export csv|json] [--redact]` *(root required)*: aggregate severity and reason trends across recent timestamped summary artifacts (default last 10 runs).
  - `--since`/`--until` accept `YYYY-MM-DD` or `YYYY-MM-DD_HHMMSS` (local time).
  - `--csv` emits a stable CSV table for imports.
  - `--redact` applies best-effort redaction to human output only (not JSON/CSV).
  - Optional cache: `LM_TREND_CACHE=1` and `LM_TREND_CACHE_TTL=60` to reuse recent computations.

Example (`trend --json`):

```json
{
  "runs": [
    {
      "file": "/var/log/health/full_health_monitor_summary_2026-02-20_120000.log",
      "totals": { "CRIT": 1, "WARN": 2, "UNKNOWN": 0, "SKIP": 0, "OK": 12 }
    }
  ],
  "totals": { "CRIT": 1, "WARN": 2, "UNKNOWN": 0, "SKIP": 0, "OK": 12 },
  "reasons": [
    { "reason": "ssh_unreachable", "count": 4 },
    { "reason": "security_updates_pending", "count": 2 }
  ]
}
```

Schema:
- `docs/schemas/trend.json` — JSON schema for `linux-maint trend --json`.

- `linux-maint export --json` *(root required)*: export a single JSON payload containing summary_result/summary_hosts plus raw `monitor=` rows (best for external ingestion).
- `linux-maint export --csv` *(root required)*: export `monitor,host,status,reason` rows as CSV (easy to import).
- `linux-maint self-check [--json]`: quick validation for config/paths/deps (safe in repo mode).

Export allowlist:
- `LM_EXPORT_ALLOWLIST=monitor,host,status,reason,...` filters **row keys** in `export --json` output (core identity fields are always included).

Schema:
- `docs/schemas/export.json` — JSON schema for `linux-maint export --json`.

Example (`export --json`):

```json
{
  "mode": "installed",
  "summary_result": { "overall": "OK", "ok": 18, "warn": 0, "crit": 0, "unknown": 0, "skipped": 0 },
  "summary_hosts": { "ok": 18, "warn": 0, "crit": 0, "unknown": 0, "skipped": 0 },
  "rows": [
    { "monitor": "health_monitor", "host": "server-a", "status": "OK" }
  ]
}
```

- `linux-maint logs [n]` *(root required)*: tail the latest wrapper log (default `n=200`).

- `linux-maint preflight` *(root recommended)*: check dependencies/SSH/config readiness.

- `linux-maint validate` *(root recommended)*: validate `/etc/linux_maint` config file formats (best-effort).

- `linux-maint version`: show installed `BUILD_INFO` (if present).

- `linux-maint install [args]`: run `./install.sh` from a checkout (pass-through).

- `linux-maint uninstall [args]`: run `./install.sh --uninstall` from a checkout (pass-through).

- `linux-maint make-tarball`: build an offline tarball (see below).

- `linux-maint deps`: print an offline dependency manifest by monitor (required vs optional commands + local availability counters).



### Environment

- `LM_REDACT_LOGS=1` — redact common secret patterns from logs and summary lines (best-effort). When enabled, values like `password=...`, `token=...`, and JWT-like blobs are replaced with `REDACTED` in emitted log/summary lines.
- `LM_REDACT_LOGS=1` also redacts values in `linux-maint export --json` output.
- `LM_REDACT_LOGS=1` also redacts log content inside `linux-maint pack-logs` bundles.
- `LM_REDACT_JSON=1` — redact common secret patterns in JSON outputs (status/report/trend/export/metrics).
- `LM_EXPORT_ALLOWLIST=monitor,host,status,reason,...` — restrict keys emitted for each row in `linux-maint export --json`.
- `LM_PACK_LOGS_HASH=1` — include `meta/bundle_hashes.txt` (SHA256 per file) in pack-logs bundles.
- `LM_PROGRESS=0` — disable progress bars (run, pack-logs, baseline update).
- `LM_PROGRESS_WIDTH=24` — progress bar width in characters.
- `LM_HOST_PROGRESS=1` — show per-host progress in host loops (used by baseline updates).
- `LM_FORCE_COLOR=1` — force ANSI color even when output is not a TTY.
- `NO_COLOR=1` / `LM_NO_COLOR=1` — disable ANSI color (overrides `LM_FORCE_COLOR`).
- `LM_STRICT=1` — wrapper strict mode (same as `linux-maint run --strict`) to fail on malformed summary lines.
- `LM_TEST_MODE=1` — deterministic test mode (disables notify/email/progress and freezes timestamps unless `LM_TEST_TIME_EPOCH` is already set).
- `LM_TEST_TIME_EPOCH=<unix_epoch>` — test-only override to freeze wrapper timestamps and filenames for deterministic output.
- `LM_SUMMARY_ALLOWLIST=key1,key2,...` — optional allowlist of summary keys to keep; extra keys are dropped with a warning.
- `LM_SUMMARY_STRICT=1` — enforce required summary fields and valid statuses at emission time (tests/CI).
- `LM_SSH_ALLOWLIST=pattern1,pattern2` — optional regex allowlist for commands sent via SSH; non-matching commands are blocked.
- `LM_SSH_ALLOWLIST_STRICT=1` — treat allowlist violations as hard errors (emits ERROR and returns rc=2).
- `LM_SSH_RETRY=N` — retry failed SSH commands up to N times with exponential backoff.
- `LM_LOG_FORMAT=json` — emit JSON logs from `lm_log` (one JSON object per line).


### SSH security defaults (fleet mode)

By default, `LM_SSH_OPTS` is set by `lib/linux_maint.sh` and is used by `lm_ssh()` for all remote execution.

Default `LM_SSH_OPTS` (as shipped):

- `BatchMode=yes`
- `ConnectTimeout=7`
- `ServerAliveInterval=10`, `ServerAliveCountMax=2`
- `StrictHostKeyChecking=accept-new` (override with `LM_SSH_KNOWN_HOSTS_MODE=strict`)
- `UserKnownHostsFile=/var/lib/linux_maint/known_hosts`
- `GlobalKnownHostsFile=/dev/null`

This avoids modifying root’s `~/.ssh/known_hosts` and reduces MITM risk compared to `StrictHostKeyChecking=no`.
You can override via `linux-maint run --ssh-opts "..."` or environment `LM_SSH_OPTS`.

Notes:
- This project intentionally splits `LM_SSH_OPTS` into ssh argv. Avoid shell metacharacters; prefer only `-o Key=Value` style options.
- If you enable strict host key verification in your environment, pre-populate the dedicated known_hosts file used by `UserKnownHostsFile`.
- `LM_SSH_KNOWN_HOSTS_MODE=strict|accept-new` toggles `StrictHostKeyChecking` when `LM_SSH_OPTS` is not explicitly set.
- `LM_SSH_KNOWN_HOSTS_PIN_FILE=/path/known_hosts` pins to a specific file and forces strict host key checking.

Seeding `known_hosts` for strict mode:

```bash
# repo mode
sudo ./tools/seed_known_hosts.sh --hosts-file /etc/linux_maint/servers.txt

# installed mode
sudo /usr/local/libexec/linux_maint/seed_known_hosts.sh --hosts-file /etc/linux_maint/servers.txt
```

Verify known_hosts entries (detect key changes):

```bash
sudo /usr/local/libexec/linux_maint/seed_known_hosts.sh --hosts-file /etc/linux_maint/servers.txt --check
```

Recommended `LM_SSH_ALLOWLIST` example (place in `/etc/linux_maint/linux-maint.conf`):

```bash
LM_SSH_ALLOWLIST='^bash -lc |^command -v |^df |^ss |^netstat |^systemctl |^ping |^nc |^curl |^timeout |^chronyc |^ntpq |^timedatectl |^mountpoint |^stat |^uname '
```

Start with a broad allowlist, then tighten it based on blocked-command warnings in logs.

Validation guardrails (in `linux-maint run`):

### Least-privilege guidance (SSH mode)

For production, prefer running the wrapper as root on each host. If you need least-privilege SSH:

1. Create a dedicated user (e.g., `linuxmaint`) with a locked-down SSH key.
2. Restrict the key with a forced command:

```
command="sudo /usr/local/sbin/run_full_health_monitor.sh",no-port-forwarding,no-agent-forwarding,no-X11-forwarding ssh-ed25519 AAAA...
```

3. Add a sudoers entry allowing only the wrapper (and optionally read-only commands like `linux-maint status` on the runner):

```
# /etc/sudoers.d/linux-maint
linuxmaint ALL=(root) NOPASSWD: /usr/local/sbin/run_full_health_monitor.sh
linuxmaint ALL=(root) NOPASSWD: /usr/local/bin/linux-maint status, /usr/local/bin/linux-maint doctor, /usr/local/bin/linux-maint logs
```

Adjust paths if your `PREFIX` is not `/usr/local`.
- Unsafe shell metacharacters are rejected in `--ssh-opts` / `LM_SSH_OPTS` with exit code `2`.
- Rejected patterns include: `;`, `&`, `|`, `` ` ``, `<`, `>`, `$(`, `${`, and newline/carriage-return bytes.

Recommended safe examples:

```bash
linux-maint run --ssh-opts "-o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new"
linux-maint run --ssh-opts "-o UserKnownHostsFile=/var/lib/linux_maint/known_hosts -o GlobalKnownHostsFile=/dev/null"
```




- `PREFIX` (default: `/usr/local`) overrides installed locations.



### Root requirement



Installed mode writes logs/locks under `/var/log` and `/var/lock` and may require privileged access for some checks.

Use `sudo linux-maint <command>` when in doubt.




```text
/usr/local/sbin/run_full_health_monitor.sh
/usr/local/lib/linux_maint.sh
/usr/local/libexec/linux_maint/
  backup_check.sh
  cert_monitor.sh
  config_drift_monitor.sh
  health_monitor.sh
  inode_monitor.sh
  inventory_export.sh
  network_monitor.sh
  nfs_mount_monitor.sh
  ntp_drift_monitor.sh
  patch_monitor.sh
  storage_health_monitor.sh
  kernel_events_monitor.sh
  ports_baseline_monitor.sh
  service_monitor.sh
  user_monitor.sh

/etc/linux_maint/
  servers.txt
  excluded.txt
  services.txt
  network_targets.txt
  certs.txt
  ports_baseline.txt
  config_paths.txt
  backup_targets.csv
  baseline_users.txt
  baseline_sudoers.txt
  baselines/

/var/log/health/
  full_health_monitor_latest.log
```


## What runs in the nightly "full package" (cron)
The system cron (root) runs the wrapper:

```bash
/usr/local/sbin/run_full_health_monitor.sh
```

That wrapper executes these scripts (in order):

- `health_monitor.sh` – snapshot: uptime, load, CPU/mem, disk usage, top processes
- `inode_monitor.sh` – inode usage thresholds
- `network_monitor.sh` – ping/tcp/http checks from `/etc/linux_maint/network_targets.txt` (wrapper SKIPs when file is missing/empty)
- `service_monitor.sh` – critical service status from `/etc/linux_maint/services.txt`
- `ntp_drift_monitor.sh` – NTP/chrony/timesyncd sync and drift
- `patch_monitor.sh` – pending updates + reboot-required hints
- `cert_monitor.sh` – certificate expiry checks from `/etc/linux_maint/certs.txt`
- `nfs_mount_monitor.sh` – NFS mount presence + responsiveness checks
- `ports_baseline_monitor.sh` – detect new/removed listening ports vs baseline
- `config_drift_monitor.sh` – detect drift in critical config files vs baseline
- `user_monitor.sh` – detect user/sudoers anomalies vs baseline
- `backup_check.sh` – verify backups from `/etc/linux_maint/backup_targets.csv`
- `inventory_export.sh` – write daily inventory CSV under `/var/log/inventory/`

### Per-monitor config reference

Monitors not listed here are configuration-free (only environment overrides).

| Monitor | Config file(s) | Required? | Example line |
| --- | --- | --- | --- |
| `service_monitor.sh` | `/etc/linux_maint/services.txt` | Yes | `sshd` |
| `network_monitor.sh` | `/etc/linux_maint/network_targets.txt` | Optional (SKIP if missing/empty) | `localhost,ping,8.8.8.8` |
| `cert_monitor.sh` | `/etc/linux_maint/certs.txt` | Optional (SKIP if missing/empty) | `example.com,443` |
| `ports_baseline_monitor.sh` | `/etc/linux_maint/ports_baseline.txt` | Gate file | `enable` |
| `config_drift_monitor.sh` | `/etc/linux_maint/config_paths.txt` | Gate file | `/etc/ssh/sshd_config` |
| `user_monitor.sh` (users) | `/etc/linux_maint/baseline_users.txt` | Gate file | `enable` |
| `user_monitor.sh` (sudoers) | `/etc/linux_maint/baseline_sudoers.txt` | Gate file | `enable` |
| `backup_check.sh` | `/etc/linux_maint/backup_targets.csv` | Yes | `localhost,/backups/*.tar.gz,100,48,tar` |


### Wrapper summary counters

The wrapper emits two types of summary counters:
- `SUMMARY_RESULT ... ok/warn/crit/unknown/skipped` — per-monitor *script exit codes*
- `SUMMARY_HOSTS ok=.. warn=.. crit=.. unknown=.. skipped=..` — derived from `monitor=` lines (fleet-accurate in distributed mode)

### Wrapper log output
The wrapper writes an aggregated log to:

- `/var/log/health/full_health_monitor_latest.log`

It also writes a machine-parseable summary (only `monitor=` lines) to:

- `/var/log/health/full_health_monitor_summary_latest.log`
- `/var/log/health/full_health_monitor_summary_latest.json` *(same content as JSON array)*

This file is intended for automation/CI ingestion and is what `linux-maint status` will prefer when present.

The wrapper also appends a compact run index entry (JSONL) to:

- `/var/lib/linux_maint/run_index.jsonl` *(default; overridden by `LM_RUN_INDEX_FILE`)*

You can control retention with `LM_RUN_INDEX_KEEP` (default 200).

Run index schema:
- `docs/schemas/run_index.json` — JSON schema for each JSONL entry.
  - Each entry includes `run_index_version` (current: `1`) for compatibility.

Optional: Prometheus export (textfile collector format)

- Default path: `/var/lib/node_exporter/textfile_collector/linux_maint.prom`
- `linux_maint_overall_status` — overall run status gauge (OK=0, WARN=1, CRIT=2, UNKNOWN=3)
- `linux_maint_summary_hosts_count{status=...}` — host-level counters derived from `monitor=` lines
- `linux_maint_monitor_status_count{status=...}` — deduped monitor result counters by status
- `linux_maint_monitor_status{monitor="...",host="..."}` — per monitor/host status gauge (OK=0, WARN=1, CRIT=2, UNKNOWN/SKIP=3)
- `linux_maint_last_run_age_seconds` — seconds since the wrapper run timestamp (near 0 on fresh runs)
- `linux_maint_reason_count{reason="..."}` — top non-OK reason token counts (deduped by monitor+host, bounded by `LM_PROM_MAX_REASON_LABELS`, default 20)
- `linux_maint_monitor_runtime_ms{monitor="..."}` — per-monitor runtime in milliseconds (wrapper)
- `linux_maint_runtime_warn_count` — count of monitors exceeding runtime warn thresholds
- `LM_PROM_FORMAT=openmetrics` — append `# EOF` for OpenMetrics-compatible output.

Prometheus contract notes:
- Metric names and label keys are stable; new metrics may be added over time.
- `status` label values are stable: `ok|warn|crit|unknown|skipped` (lowercase).
- `linux_maint_monitor_status` uses the exit-code scale: `OK=0`, `WARN=1`, `CRIT=2`, `UNKNOWN/SKIP=3`.
- `linux_maint_overall_status` is the overall exit-code scale value for the last run.
- `linux_maint_reason_count` only emits the top N reasons (bounded by `LM_PROM_MAX_REASON_LABELS`), so rare reasons may be omitted.

Each script prints a **single one-line summary** to stdout so the wrapper log stays readable.

If a monitor is skipped by the wrapper due to missing config gates, the wrapper emits a standardized summary line with `status=SKIP` and a `reason=` field.
Detailed logs are still written per-script under `/var/log/*.log`.

## Configuration files under `/etc/linux_maint/`
Minimal files created/used:

- `servers.txt` – hosts list (default: `localhost`)
- `excluded.txt` – optional excluded hosts
- `services.txt` – services to check
- `network_targets.txt` – network checks (CSV)
- `certs.txt` – cert targets (one per line)
- `ports_baseline.txt` – (legacy) initial ports baseline list
- `config_paths.txt` – list of critical config paths to baseline
- `baseline_users.txt` / `baseline_sudoers.txt` – initial user/sudoers baseline inputs

Baselines created by monitors:

- `/etc/linux_maint/baselines/ports/<host>.baseline`
- `/etc/linux_maint/baselines/config/<host>.baseline` (if enabled in script)
- `/etc/linux_maint/baselines/users/<host>.users`
- `/etc/linux_maint/baselines/sudoers/<host>.sudoers`


## Optional monitors: enablement examples

Some monitors are intentionally **skipped** until you provide configuration files.
This keeps first-run output clean and avoids false alerts.

### Enable `network_monitor.sh`

Create `/etc/linux_maint/network_targets.txt` (CSV):

```bash
sudo tee /etc/linux_maint/network_targets.txt >/dev/null <<'EOF'
# host,check,target,key=value...
localhost,ping,8.8.8.8,count=3,timeout=3
localhost,tcp,1.1.1.1:443,timeout=3
localhost,http,https://example.com,timeout=5,expect=200-399
EOF
```

Notes:
- Targets must not contain spaces or shell metacharacters (quotes, backticks, `$`, `;`, `|`, `&`, `<`, `>`).
- Invalid rows are skipped and reported as `invalid_target` in alerts.

### Enable `cert_monitor.sh`

Create `/etc/linux_maint/certs.txt` (one target per line; supports optional params after `|`):

```bash
sudo tee /etc/linux_maint/certs.txt >/dev/null <<'EOF'
# host:port
example.com:443

# SNI override (when hostname differs from certificate name)
api.example.com:443|sni=api.example.com

# STARTTLS example (if you monitor SMTP)
smtp.example.com:587|starttls=smtp
EOF
```

### Enable `backup_check.sh`

Create `/etc/linux_maint/backup_targets.csv`:

```bash
sudo tee /etc/linux_maint/backup_targets.csv >/dev/null <<'EOF'
# host,pattern,max_age_hours,min_size_mb,verify
*,/backups/db/db_*.tar.gz,24,100,tar
localhost,/var/backups/etc_*.tar.gz,48,10,gzip
EOF
```

### Enable `ports_baseline_monitor.sh`

`ports_baseline_monitor.sh` maintains per-host baselines under:
- `/etc/linux_maint/baselines/ports/<host>.baseline`

The wrapper only runs this monitor when `/etc/linux_maint/ports_baseline.txt` exists.
Create it as an (optional) “gate” file (contents are not used by the monitor):

```bash
sudo install -D -m 0644 /dev/null /etc/linux_maint/ports_baseline.txt
```

On first run, the baseline will be auto-created (when `AUTO_BASELINE_INIT=true`).

### Enable `config_drift_monitor.sh`

Create `/etc/linux_maint/config_paths.txt` with one path/pattern per line:

```bash
sudo tee /etc/linux_maint/config_paths.txt >/dev/null <<'EOF'
/etc/ssh/sshd_config
/etc/sudoers
/etc/fstab
/etc/sysctl.conf
/etc/cron.d/
EOF
```

Then run the wrapper again:

```bash
sudo /usr/local/sbin/run_full_health_monitor.sh
```


## Quick manual run

### Installed mode requires root (recommended)

The installed tool writes logs/locks under `/var/log` and `/var/lock` and may need privileged access for some checks.
Run the wrapper/CLI via `sudo`, cron, or a systemd timer.

Run the full package now:

```bash
sudo /usr/local/sbin/run_full_health_monitor.sh
sudo tail -n 200 /var/log/health/full_health_monitor_latest.log
```





## Offline releases / version tracking

For a step-by-step guide, see: `docs/DARK_SITE.md`.

For dark-site environments, you can generate a versioned tarball that includes a `BUILD_INFO` file.
After installation, version info (when present) is stored at:

- `/usr/local/share/linux_maint/BUILD_INFO`

Build a tarball on a connected workstation:

```bash
./tools/make_tarball.sh
# output: dist/Linux_Maint_ToolKit-<version>-<sha>.tgz
```

Copy the tarball to the offline server, extract, then install:

```bash
tar -xzf dist/Linux_Maint_ToolKit-*.tgz
sudo ./install.sh
cat /usr/local/share/linux_maint/BUILD_INFO
```

## Air-gapped / offline installation

If your target servers cannot access GitHub/the Internet, you can still deploy this project.

On a connected workstation:

```bash
git clone https://github.com/ShenhavHezi/Linux_Maint_ToolKit.git
cd Linux_Maint_ToolKit

# Recommended: build a versioned tarball with BUILD_INFO
./tools/make_tarball.sh
# output: dist/Linux_Maint_ToolKit-<version>-<sha>.tgz
```

Copy the generated tarball from `dist/` to the dark-site server, extract, then install:

```bash
tar -xzf Linux_Maint_ToolKit-*.tgz
sudo ./install.sh --with-logrotate
# (optional)
# sudo ./install.sh --with-user --with-timer --with-logrotate
```

## RPM packaging (release workflow)

RPM packaging is available under `packaging/rpm/` (spec + systemd unit/timer + build script).

### Build the RPM (on a build host)

Prereqs:
- `rpmbuild` (RPM tooling)
- `rsync`, `tar`
- `python3` (for some tooling)

Build:

```bash
cd Linux_Maint_ToolKit
# optional: pass an explicit version; otherwise VERSION file is used
./packaging/rpm/build_rpm.sh
# or: ./packaging/rpm/build_rpm.sh 0.1.0
```

Output location is printed by the script; RPMs are placed under a temp rpmbuild tree, for example:

```text
/tmp/linux-maint-rpmbuild/RPMS/noarch/linux-maint-<version>-1.<dist>.noarch.rpm
```

### Install the RPM (on a target node)

Copy the RPM to the target node and install:

```bash
# RHEL/Fedora/CentOS/Rocky/Alma
sudo dnf install -y ./linux-maint-<version>-*.noarch.rpm
# or (older systems): sudo yum install -y ./linux-maint-<version>-*.noarch.rpm
```

Installed paths (RPM best practice):
- `/usr/bin/linux-maint`
- `/usr/sbin/run_full_health_monitor.sh`
- `/usr/lib/linux_maint.sh`
- `/usr/libexec/linux_maint/*`
- systemd units: `/usr/lib/systemd/system/linux-maint.{service,timer}`

### Enable/disable the systemd timer

The RPM `%post` script enables the timer by default. To disable that behavior at install time:

```bash
# disables auto-enable in %post
sudo LM_ENABLE_TIMER=0 dnf install -y ./linux-maint-<version>-*.noarch.rpm
```

After install, you can manage it normally:

```bash
sudo systemctl enable --now linux-maint.timer
sudo systemctl status linux-maint.timer --no-pager
# manual run:
sudo systemctl start linux-maint.service
```

### Uninstall the RPM

```bash
sudo dnf remove -y linux-maint
```

Notes:
- RPM uninstall disables the timer automatically (`%preun`).
- RPM uninstall does not remove `/etc/linux_maint` or `/var/log/health` by default; remove those explicitly if desired.

## Development / CI (appendix)

This repository includes a GitHub Actions workflow that:
- runs `shellcheck` on scripts
- verifies the README "Tuning knobs" section is in sync (`tools/update_readme_defaults.py`)


## Developer hooks (optional)

For contributors, you can enable a local pre-commit hook that runs the same checks as CI
(`shellcheck` + README tuning-knobs sync).

Enable repo-local git hooks:

```bash
git config core.hooksPath .githooks
```

Or run the checks manually:

```bash
./tools/pre-commit.sh
```

## Uninstall

Remove the installed files (does not remove your config/baselines unless you choose to):

```bash
# Programs
sudo rm -f /usr/local/sbin/run_full_health_monitor.sh
sudo rm -f /usr/local/lib/linux_maint.sh
sudo rm -rf /usr/local/libexec/linux_maint

# (Optional) configuration + baselines
sudo rm -rf /etc/linux_maint

# (Optional) logs
sudo rm -rf /var/log/health
sudo rm -f /var/log/*monitor*.log /var/log/*_monitor.log /var/log/*_check.log /var/log/inventory_export.log

# (Optional) logrotate entry
sudo rm -f /etc/logrotate.d/linux_maint
```


## Log rotation (recommended)

These scripts write logs under `/var/log/` (plus an aggregated wrapper log under `/var/log/health/`).
On most systems, these logs should be rotated.

Example `logrotate` config (create `/etc/logrotate.d/linux_maint`):

```conf
/var/log/*monitor*.log /var/log/*_monitor.log /var/log/*_check.log /var/log/inventory_export.log {
  daily
  rotate 14
  missingok
  notifempty
  compress
  delaycompress
  copytruncate
}

/var/log/health/*.log /var/log/health/*.json {
  daily
  rotate 14
  missingok
  notifempty
  compress
  delaycompress
  # These logs are written as one-shot files (not long-lived daemons), so copytruncate is unnecessary.
  # Exclude latest symlinks so they keep pointing at the newest run artifact.
  prerotate
    # Ensure we never create rotated copies of the latest symlinks
    rm -f /var/log/health/*_latest.log.* /var/log/health/*_latest.json.* 2>/dev/null || true
  endscript
}

# Do not rotate the latest symlinks (rotate=0 effectively ignores them).
/var/log/health/*_latest.log /var/log/health/*_latest.json {
  missingok
  notifempty
  rotate 0
}
```
Notes:
- The per-monitor logs under `/var/log/` use `copytruncate` so rotation is safe even if a script is still writing.
- The wrapper artifacts under `/var/log/health/` are one-shot files; `copytruncate` is intentionally not used there.
- Latest symlinks (`*_latest.*`) are excluded from rotation so they keep pointing at the newest run artifact.

## Upgrading

To upgrade on a node where you installed using the recommended paths:

```bash
cd /path/to/Linux_Maint_ToolKit
git pull

sudo install -D -m 0755 lib/linux_maint.sh /usr/local/lib/linux_maint.sh
sudo install -D -m 0755 run_full_health_monitor.sh /usr/local/sbin/run_full_health_monitor.sh
sudo install -D -m 0755 monitors/*.sh /usr/local/libexec/linux_maint/
```

After upgrading:
- Review `git diff` for config file name changes.
- Re-run the wrapper once and check: `/var/log/health/full_health_monitor_latest.log`.

### Diff state file (`linux-maint diff`)
`linux-maint diff` compares the latest summary against a persisted copy from the previous run.
`linux-maint diff` first canonicalizes repeated `monitor`+`host` rows using **worst-status-wins** semantics (`UNKNOWN` > `CRIT` > `WARN` > `OK/SKIP`), with last-wins tie-break when severity is equal.
Text output is colorized when color is enabled; set `NO_COLOR=1` to disable.

The wrapper persists the previous summary monitor-lines file at (best-effort):

- `${LM_NOTIFY_STATE_DIR:-${LM_STATE_DIR:-/var/lib/linux_maint}}/last_summary_monitor_lines.log`

By default, installed mode should use `/var/lib/linux_maint/last_summary_monitor_lines.log`.

CERTS_SCAN_DIR (optional): if set, cert_monitor scans this directory for cert files (offline expiry check).
CERTS_SCAN_IGNORE_FILE: file with ignore patterns (substring match) to skip paths (default /etc/linux_maint/certs_scan_ignore.txt).
CERTS_SCAN_EXTS: comma-separated extensions to include (default crt,cer,pem).
- `linux-maint config --lint` *(root required)*: validate config file syntax and detect duplicate keys.

- `linux-maint baseline <ports|configs|users|sudoers> --update` *(root required)*: capture/update baselines (per-host).
  - `--progress|--no-progress`: enable/disable per-host progress (overrides `LM_PROGRESS`).

- `linux-maint doctor --fix` *(root required)*: attempt safe dependency fixes (use `--dry-run` to preview).

- `linux-maint help <command>`: show concise usage for a specific command (no root required). For full flag details, see this reference.

- `linux-maint pack-logs [--out DIR]`: create a support bundle (progress can be toggled with `--progress|--no-progress`).
  - `--redact|--no-redact`: override `LM_REDACT_LOGS` for this bundle only.
  - `--hash`: include `meta/bundle_hashes.txt` (SHA256 per file) in the bundle.
