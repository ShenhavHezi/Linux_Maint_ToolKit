#!/usr/bin/env bash
set -euo pipefail

# Repo-portable runner: place this file on a server and install to /usr/local/sbin/
# It expects the repo scripts under /usr/local/libexec/linux_maint by default.

# Default install location (can be overridden)
SCRIPTS_DIR_BASE="${SCRIPTS_DIR:-/usr/local/libexec/linux_maint}"
REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
lm_now_epoch() {
  if [[ -n "${LM_TEST_TIME_EPOCH:-}" ]] && [[ "${LM_TEST_TIME_EPOCH}" =~ ^[0-9]+$ ]]; then
    printf '%s' "${LM_TEST_TIME_EPOCH}"
  else
    date +%s
  fi
}

lm_now_iso() {
  if [[ -n "${LM_TEST_TIME_EPOCH:-}" ]] && [[ "${LM_TEST_TIME_EPOCH}" =~ ^[0-9]+$ ]]; then
    date -Is -d "@${LM_TEST_TIME_EPOCH}"
  else
    date -Is
  fi
}

lm_now_stamp() {
  if [[ -n "${LM_TEST_TIME_EPOCH:-}" ]] && [[ "${LM_TEST_TIME_EPOCH}" =~ ^[0-9]+$ ]]; then
    date -d "@${LM_TEST_TIME_EPOCH}" +%F_%H%M%S
  else
    date +%F_%H%M%S
  fi
}

if [[ -d "$REPO_DIR/monitors" ]]; then
  SCRIPTS_DIR_DEFAULT="$REPO_DIR/monitors"
else
  SCRIPTS_DIR_DEFAULT="$SCRIPTS_DIR_BASE"
fi
SCRIPTS_DIR="${SCRIPTS_DIR:-$SCRIPTS_DIR_DEFAULT}"

# Ensure monitors use the repo library when running from a checkout
if [[ -f "$REPO_DIR/lib/linux_maint.sh" ]]; then
  export LINUX_MAINT_LIB="$REPO_DIR/lib/linux_maint.sh"
fi
export LINUX_MAINT_LIB="${LINUX_MAINT_LIB:-/usr/local/lib/linux_maint.sh}"
export LM_LOCKDIR="${LM_LOCKDIR:-/tmp}"

# Load optional notification config (wrapper-level). Default OFF.
if [[ -f "${LINUX_MAINT_LIB:-/usr/local/lib/linux_maint.sh}" ]]; then
  # shellcheck disable=SC1090
  . "${LINUX_MAINT_LIB:-/usr/local/lib/linux_maint.sh}" >/dev/null 2>&1 || true
  if command -v lm_load_notify_conf >/dev/null 2>&1; then
    lm_load_notify_conf || true
  fi
fi


if [[ -d "$REPO_DIR/monitors" ]]; then
  LOG_DIR_DEFAULT="$REPO_DIR/.logs"
  STATE_DIR_DEFAULT="/tmp"
else
  LOG_DIR_DEFAULT="/var/log/health"
  STATE_DIR_DEFAULT="/var/lib/linux_maint"
fi

# Load installed configuration files (best-effort).
CONF_LIB=""
if [ -f "$REPO_DIR/lib/linux_maint_conf.sh" ]; then
  CONF_LIB="$REPO_DIR/lib/linux_maint_conf.sh"
elif [[ "$LINUX_MAINT_LIB" == */linux_maint.sh ]]; then
  maybe_conf="${LINUX_MAINT_LIB%/linux_maint.sh}/linux_maint_conf.sh"
  [ -f "$maybe_conf" ] && CONF_LIB="$maybe_conf"
elif [ -f "/usr/local/lib/linux_maint_conf.sh" ]; then
  CONF_LIB="/usr/local/lib/linux_maint_conf.sh"
fi

if [ -n "$CONF_LIB" ] && [ -f "$CONF_LIB" ]; then
  # shellcheck disable=SC1090
  . "$CONF_LIB" || true
  if command -v lm_load_config >/dev/null 2>&1; then lm_load_config || true; fi
fi

# Resolve state dir with fallback chain (writable-required)
STATE_DIR_REQUESTED="${LM_STATE_DIR:-$STATE_DIR_DEFAULT}"
STATE_DIR_FALLBACK_FROM=""
STATE_DIR_FALLBACK_TO=""
if command -v lm_pick_writable_dir >/dev/null 2>&1; then
  if STATE_DIR_CHOSEN="$(lm_pick_writable_dir "state" "$STATE_DIR_REQUESTED" "/var/tmp/linux_maint" "/tmp/linux_maint" "${TMPDIR:-/tmp}/linux_maint")"; then
    export LM_STATE_DIR="$STATE_DIR_CHOSEN"
    if [[ "$STATE_DIR_CHOSEN" != "$STATE_DIR_REQUESTED" ]]; then
      STATE_DIR_FALLBACK_FROM="$STATE_DIR_REQUESTED"
      STATE_DIR_FALLBACK_TO="$STATE_DIR_CHOSEN"
    fi
  else
    echo "ERROR: no writable state directory found (requested=$STATE_DIR_REQUESTED)" >&2
    exit 3
  fi
else
  export LM_STATE_DIR="$STATE_DIR_REQUESTED"
fi

# Resolve log dir with fallback chain (writable-required)
LOG_DIR_REQUESTED="${LOG_DIR:-$LOG_DIR_DEFAULT}"
LOG_DIR_FALLBACK_FROM=""
LOG_DIR_FALLBACK_TO=""
if command -v lm_pick_writable_dir >/dev/null 2>&1; then
  if LOG_DIR_CHOSEN="$(lm_pick_writable_dir "logs" "$LOG_DIR_REQUESTED" "/var/tmp/linux_maint/logs" "/tmp/linux_maint/logs" "${TMPDIR:-/tmp}/linux_maint/logs")"; then
    LOG_DIR="$LOG_DIR_CHOSEN"
    if [[ "$LOG_DIR_CHOSEN" != "$LOG_DIR_REQUESTED" ]]; then
      LOG_DIR_FALLBACK_FROM="$LOG_DIR_REQUESTED"
      LOG_DIR_FALLBACK_TO="$LOG_DIR_CHOSEN"
    fi
  else
    echo "ERROR: no writable log directory found (requested=$LOG_DIR_REQUESTED)" >&2
    exit 3
  fi
else
  LOG_DIR="$LOG_DIR_REQUESTED"
  mkdir -p "$LOG_DIR" 2>/dev/null || true
fi

STATUS_FILE="$LOG_DIR/last_status_full"

mkdir -p "$LOG_DIR" 2>/dev/null || true
chmod 0755 "$LOG_DIR" 2>/dev/null || true

logfile="$LOG_DIR/full_health_monitor_$(lm_now_stamp).log"

# Resolve temp dir (for wrapper temp files) with fallback chain.
TMPDIR_REQUESTED="${TMPDIR:-/tmp}"
if command -v lm_pick_writable_dir >/dev/null 2>&1; then
  TMPDIR="$(lm_pick_writable_dir "tmp" "$TMPDIR_REQUESTED" "/var/tmp" "/tmp" 2>/dev/null || echo "/tmp")"
else
  TMPDIR="$TMPDIR_REQUESTED"
fi
mkdir -p "$TMPDIR" 2>/dev/null || true
export TMPDIR

tmp_report="$TMPDIR/full_health_monitor_report.$$"
tmp_summary="$TMPDIR/full_health_monitor_summary.$$"

# Optional: write machine-parseable summaries to a separate file
# Defaults to /var/log/health/full_health_monitor_summary_latest.log
SUMMARY_DIR_REQUESTED="${SUMMARY_DIR:-$LOG_DIR}"
SUMMARY_DIR_FALLBACK_FROM=""
SUMMARY_DIR_FALLBACK_TO=""
if command -v lm_pick_writable_dir >/dev/null 2>&1; then
  if SUMMARY_DIR_CHOSEN="$(lm_pick_writable_dir "summary" "$SUMMARY_DIR_REQUESTED" "/var/tmp/linux_maint/logs" "/tmp/linux_maint/logs" "${TMPDIR:-/tmp}/linux_maint/logs")"; then
    SUMMARY_DIR="$SUMMARY_DIR_CHOSEN"
    if [[ "$SUMMARY_DIR_CHOSEN" != "$SUMMARY_DIR_REQUESTED" ]]; then
      SUMMARY_DIR_FALLBACK_FROM="$SUMMARY_DIR_REQUESTED"
      SUMMARY_DIR_FALLBACK_TO="$SUMMARY_DIR_CHOSEN"
    fi
  else
    echo "ERROR: no writable summary directory found (requested=$SUMMARY_DIR_REQUESTED)" >&2
    exit 3
  fi
else
  SUMMARY_DIR="$SUMMARY_DIR_REQUESTED"
  mkdir -p "$SUMMARY_DIR" 2>/dev/null || true
fi

SUMMARY_LATEST_FILE="${SUMMARY_LATEST_FILE:-$SUMMARY_DIR/full_health_monitor_summary_latest.log}"
SUMMARY_JSON_LATEST_FILE="${SUMMARY_JSON_LATEST_FILE:-$SUMMARY_DIR/full_health_monitor_summary_latest.json}"
SUMMARY_JSON_FILE="${SUMMARY_JSON_FILE:-$SUMMARY_DIR/full_health_monitor_summary_$(lm_now_stamp).json}"
PROM_DIR="${PROM_DIR:-/var/lib/node_exporter/textfile_collector}"
PROM_FILE="${PROM_FILE:-$PROM_DIR/linux_maint.prom}"
SUMMARY_FILE="${SUMMARY_FILE:-$SUMMARY_DIR/full_health_monitor_summary_$(lm_now_stamp).log}"
trap 'rm -f "$tmp_summary"' EXIT

# Minimal config (local mode)
# Minimal config (local mode)
# In unprivileged environments (e.g. CI), fall back to a repo-local config dir.
CFG_DIR="${LM_CFG_DIR:-/etc/linux_maint}"
if ! mkdir -p "$CFG_DIR" 2>/dev/null; then
  CFG_DIR="${LM_CFG_DIR_FALLBACK:-$REPO_DIR/.etc_linux_maint}"
  mkdir -p "$CFG_DIR"
fi
[ -f "$CFG_DIR/servers.txt" ] || echo "localhost" > "$CFG_DIR/servers.txt"
[ -f "$CFG_DIR/excluded.txt" ] || : > "$CFG_DIR/excluded.txt"

# Point library defaults at our chosen config directory (do not override explicit env).
export LM_SERVERLIST="${LM_SERVERLIST:-$CFG_DIR/servers.txt}"
export LM_EXCLUDED="${LM_EXCLUDED:-$CFG_DIR/excluded.txt}"
export LM_SERVICES="${LM_SERVICES:-$CFG_DIR/services.txt}"

# Dark-site profile: optional conservative defaults for air-gapped operators.
# Never override explicit values set by config/env/CLI.
if [[ "${LM_DARK_SITE:-false}" == "true" ]]; then
  export LM_LOCAL_ONLY="${LM_LOCAL_ONLY:-true}"
  export LM_NOTIFY_ONLY_ON_CHANGE="${LM_NOTIFY_ONLY_ON_CHANGE:-1}"
  MONITOR_TIMEOUT_SECS="${MONITOR_TIMEOUT_SECS:-300}"
else
  MONITOR_TIMEOUT_SECS="${MONITOR_TIMEOUT_SECS:-600}"
fi


# service_monitor requires services.txt; provide safe defaults if missing
if [ ! -s "$CFG_DIR/services.txt" ]; then
  cat > "$CFG_DIR/services.txt" <<'SVC'
# critical services
sshd
crond
docker
NetworkManager
SVC
  chmod 0644 "$CFG_DIR/services.txt"
fi

# Disable email unless explicitly enabled
export LM_EMAIL_ENABLED="${LM_EMAIL_ENABLED:-false}"

# Optional per-monitor timeouts (format: monitor_name=seconds)
# Example file: /etc/linux_maint/monitor_timeouts.conf
MONITOR_TIMEOUTS_FILE="${MONITOR_TIMEOUTS_FILE:-$CFG_DIR/monitor_timeouts.conf}"

# Optional per-monitor runtime warn thresholds (seconds)
# Example file: /etc/linux_maint/monitor_runtime_warn.conf
MONITOR_RUNTIME_WARN_FILE="${MONITOR_RUNTIME_WARN_FILE:-$CFG_DIR/monitor_runtime_warn.conf}"

get_monitor_timeout_secs(){
  local monitor_name="$1" # without .sh
  local default_secs="$2"

  [ -f "$MONITOR_TIMEOUTS_FILE" ] || { echo "$default_secs"; return 0; }

  local line
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      ''|'#'*) continue;;
    esac
    case "$line" in
      "$monitor_name"=*)
        local val="${line#*=}"
        if [[ "$val" =~ ^[0-9]+$ ]] && [ "$val" -gt 0 ]; then
          echo "$val"
        else
          echo "$default_secs"
        fi
        return 0
        ;;
    esac
  done < "$MONITOR_TIMEOUTS_FILE"

  echo "$default_secs"
}

get_monitor_runtime_warn_secs(){
  local monitor_name="$1" # without .sh
  local default_secs="${2:-0}"

  [ -f "$MONITOR_RUNTIME_WARN_FILE" ] || { echo "$default_secs"; return 0; }

  local line
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      ''|'#'*) continue;;
    esac
    case "$line" in
      "$monitor_name"=*)
        local val="${line#*=}"
        if [[ "$val" =~ ^[0-9]+$ ]] && [ "$val" -gt 0 ]; then
          echo "$val"
        else
          echo "$default_secs"
        fi
        return 0
        ;;
    esac
  done < "$MONITOR_RUNTIME_WARN_FILE"

  echo "$default_secs"
}

# health_monitor already includes: uptime/load/cpu/mem/disk/top processes.
# Avoid overlaps by excluding disk_monitor/process_hog/server_info.

declare -a scripts=(


  "preflight_check.sh"
  "config_validate.sh"
  "health_monitor.sh"
  "filesystem_readonly_monitor.sh"
  "resource_monitor.sh"
  "inode_monitor.sh"
  "disk_trend_monitor.sh"
  "network_monitor.sh"
  "service_monitor.sh"
  "timer_monitor.sh"
  "last_run_age_monitor.sh"
  "ntp_drift_monitor.sh"
  "patch_monitor.sh"
  "storage_health_monitor.sh"
  "kernel_events_monitor.sh"
  "log_spike_monitor.sh"
  "cert_monitor.sh"
  "nfs_mount_monitor.sh"
  "ports_baseline_monitor.sh"
  "config_drift_monitor.sh"
  "user_monitor.sh"
  "backup_check.sh"
  "inventory_export.sh"
)


# Allow overriding the monitor list (useful for tests / minimal runs).
# Format: LM_MONITORS="a.sh b.sh"
if [[ -n "${LM_MONITORS:-}" ]]; then
  # shellcheck disable=SC2206
  scripts=(${LM_MONITORS})
fi

{
  echo "SUMMARY full_health_monitor host=$(hostname -f 2>/dev/null || hostname) started=$(lm_now_iso)"
  echo "SCRIPTS_DIR=$SCRIPTS_DIR"
  echo "LM_EMAIL_ENABLED=$LM_EMAIL_ENABLED"
  echo "LM_DARK_SITE=${LM_DARK_SITE:-false}"
  echo "LM_LOCAL_ONLY=${LM_LOCAL_ONLY:-false}"
  echo "MONITOR_TIMEOUT_SECS=$MONITOR_TIMEOUT_SECS"
  echo "SCRIPT_ORDER=${scripts[*]}"
  echo "============================================================"
} > "$tmp_report"

# Emit explicit warnings if we had to fall back to alternate writable dirs.
if [[ -n "$LOG_DIR_FALLBACK_TO" ]]; then
  echo "WARN: log dir fallback from $LOG_DIR_FALLBACK_FROM to $LOG_DIR_FALLBACK_TO" >> "$tmp_report"
  echo "monitor=wrapper host=runner status=WARN reason=log_dir_fallback from=$LOG_DIR_FALLBACK_FROM to=$LOG_DIR_FALLBACK_TO" >> "$tmp_report"
fi
if [[ -n "$SUMMARY_DIR_FALLBACK_TO" ]]; then
  echo "WARN: summary dir fallback from $SUMMARY_DIR_FALLBACK_FROM to $SUMMARY_DIR_FALLBACK_TO" >> "$tmp_report"
  echo "monitor=wrapper host=runner status=WARN reason=summary_dir_fallback from=$SUMMARY_DIR_FALLBACK_FROM to=$SUMMARY_DIR_FALLBACK_TO" >> "$tmp_report"
fi
if [[ -n "$STATE_DIR_FALLBACK_TO" ]]; then
  echo "WARN: state dir fallback from $STATE_DIR_FALLBACK_FROM to $STATE_DIR_FALLBACK_TO" >> "$tmp_report"
  echo "monitor=wrapper host=runner status=WARN reason=state_dir_fallback from=$STATE_DIR_FALLBACK_FROM to=$STATE_DIR_FALLBACK_TO" >> "$tmp_report"
fi

run_one() {
  local s="$1"
  local monitor_name="${s%.sh}"
  local rc
  local path="$SCRIPTS_DIR/$s"
  echo "" >> "$tmp_report"
  echo "==== RUN $s @ $(date '+%F %T') ====" >> "$tmp_report"

  # Emit standardized SKIP summary lines when wrapper gates skip a monitor
  skip_monitor() {
    local reason="$1"
    echo "SKIP: $reason" >> "$tmp_report"
    echo "monitor=${s%.sh} host=all status=SKIP node=$(hostname -f 2>/dev/null || hostname) reason=$reason" >> "$tmp_report"
    skipped=$((skipped+1))
    return 0
  }

  # Skip monitors that require optional config/baselines unless present.
  # Use CFG_DIR so repo/unprivileged runs and dark-site deployments can keep
  # local config without writing to /etc.
  case "$s" in
    cert_monitor.sh)
      [ -s "$CFG_DIR/certs.txt" ] || { skip_monitor "missing:$CFG_DIR/certs.txt"; }
      ;;
    network_monitor.sh)
      [ -s "$CFG_DIR/network_targets.txt" ] || { skip_monitor "missing:$CFG_DIR/network_targets.txt"; }
      ;;
    ports_baseline_monitor.sh)
      [ -s "$CFG_DIR/ports_baseline.txt" ] || { skip_monitor "missing:$CFG_DIR/ports_baseline.txt"; }
      ;;
    config_drift_monitor.sh)
      [ -s "$CFG_DIR/config_paths.txt" ] || { skip_monitor "missing:$CFG_DIR/config_paths.txt"; }
      ;;
    user_monitor.sh)
      [ -s "$CFG_DIR/baseline_users.txt" ] || { skip_monitor "missing:$CFG_DIR/baseline_users.txt"; }
      [ -s "$CFG_DIR/baseline_sudoers.txt" ] || { skip_monitor "missing:$CFG_DIR/baseline_sudoers.txt"; }
      ;;
  esac

  if [ ! -f "$path" ]; then
    echo "MISSING: $path" >> "$tmp_report"
    return 3
  fi

  if [ "$s" = "config_validate.sh" ]; then
    # Validation warnings should not fail the full run; log output but ignore exit code.
    bash "$path" >> "$tmp_report" 2>&1 || true
    return 0
  fi

  # Wrapper-level timeout to prevent a single monitor from hanging the whole run
  if command -v timeout >/dev/null 2>&1; then
    local secs
    secs="$(get_monitor_timeout_secs "$monitor_name" "$MONITOR_TIMEOUT_SECS")"
    timeout "$secs" bash "$path" >> "$tmp_report" 2>&1
  rc=$?
    if [ "$rc" -eq 124 ]; then
      echo "monitor=$monitor_name host=runner status=UNKNOWN node=$(hostname -f 2>/dev/null || hostname) reason=timeout timeout_secs=$secs" >> "$tmp_report"
      return 3
    fi
    return "$rc"
  else
    bash "$path" >> "$tmp_report" 2>&1
  fi
}

skipped=0
worst=0
ok=0; warn=0; crit=0; unk=0
declare -A runtime_ms=()
runtime_warned=0
runtime_warn_count=0
runtime_file="$TMPDIR/linux_maint_runtime.$$"

now_ms(){
  date +%s%3N 2>/dev/null || echo $(( $(date +%s) * 1000 ))
}

for s in "${scripts[@]}"; do
  set +e
  start_ms="$(now_ms)"
  before_lines=$(grep -a -c "^monitor=" "$tmp_report" 2>/dev/null || true)
  before_lines=${before_lines:-0}
  run_one "$s"
  rc=$?
  after_lines=$(grep -a -c "^monitor=" "$tmp_report" 2>/dev/null || true)
  after_lines=${after_lines:-0}
  end_ms="$(now_ms)"
  if [[ "$end_ms" =~ ^[0-9]+$ && "$start_ms" =~ ^[0-9]+$ ]]; then
    runtime_ms["${s%.sh}"]=$((end_ms - start_ms))
  fi
  if [ "$rc" -ne 0 ] && [ "$after_lines" -le "$before_lines" ]; then
    # Hardening: a monitor failed but emitted no standardized summary line.
    echo "monitor=${s%.sh} host=runner status=UNKNOWN node=$(hostname -f 2>/dev/null || hostname) reason=early_exit rc=$rc" >> "$tmp_report"
  fi
  set -e

  case "$rc" in
    0) ok=$((ok+1));;
    1) warn=$((warn+1));;
    2) crit=$((crit+1));;
    *) unk=$((unk+1)); rc=3;;
  esac
  [ "$rc" -gt "$worst" ] && worst="$rc"
done

# Persist runtime data for downstream outputs (prometheus).
: > "$runtime_file" 2>/dev/null || true
for mon in "${!runtime_ms[@]}"; do
  echo "monitor=$mon ms=${runtime_ms[$mon]}" >> "$runtime_file" 2>/dev/null || true
done

# Runtime warn thresholds (synthetic wrapper guard)
for mon in "${!runtime_ms[@]}"; do
  ms="${runtime_ms[$mon]}"
  [[ "$ms" =~ ^[0-9]+$ ]] || continue
  warn_secs="$(get_monitor_runtime_warn_secs "$mon" "0")"
  [[ "$warn_secs" =~ ^[0-9]+$ ]] || warn_secs=0
  if [ "$warn_secs" -gt 0 ] && [ "$ms" -ge $((warn_secs * 1000)) ]; then
    runtime_warned=1
    runtime_warn_count=$((runtime_warn_count+1))
    echo "monitor=runtime_guard host=runner status=WARN reason=runtime_exceeded target_monitor=$mon runtime_ms=$ms threshold_ms=$((warn_secs * 1000))" >> "$tmp_report"
  fi
done
if [ "$runtime_warned" -eq 1 ]; then
  warn=$((warn+runtime_warn_count))
  [ "$worst" -lt 1 ] && worst=1
fi

case "$worst" in
  0) overall="OK";;
  1) overall="WARN";;
  2) overall="CRIT";;
  *) overall="UNKNOWN";;
esac

ts_epoch="$(lm_now_epoch)"
{
  echo "SUMMARY_RESULT overall=$overall ok=$ok warn=$warn crit=$crit unknown=$unk skipped=$skipped finished=$(lm_now_iso) exit_code=$worst"
  echo "SUMMARY_MONITORS ok=$ok warn=$warn crit=$crit unknown=$unk skipped=$skipped"
  echo "SUMMARY_RESULT_NOTE SUMMARY_RESULT counts are per-monitor-script exit codes (plus runtime_guard if enabled); fleet counters are in SUMMARY_HOSTS derived from monitor= lines"
  echo "============================================================"
  # Final status summary: explicitly extract only standardized machine lines.
  # These come from lib/linux_maint.sh: lm_summary() -> lines starting with "monitor=".
  echo "FINAL_STATUS_SUMMARY (monitor= lines only)"
  tmp_mon=$(mktemp -p "$TMPDIR" linux_maint_mon.XXXXXX)
  grep -a '^monitor=' "$tmp_report" > "$tmp_mon" || true
  cat "$tmp_mon" 2>/dev/null || true
  echo "============================================================"

# ------------------------
# HUMAN_STATUS_SUMMARY (ops-friendly)
# ------------------------
# Avoid reading+appending to the same file in one block: snapshot monitor lines first.
_tmp_mon_snapshot=$(mktemp -p "$TMPDIR" linux_maint_mon_snapshot.XXXXXX)
grep -a '^monitor=' "$tmp_report" > "$_tmp_mon_snapshot" 2>/dev/null || true

# shellcheck disable=SC2030
# shellcheck disable=SC2030
hosts_ok=0
# shellcheck disable=SC2030
hosts_warn=0
# shellcheck disable=SC2030
hosts_crit=0
# shellcheck disable=SC2030
hosts_unknown=0
# shellcheck disable=SC2030
hosts_skip=0
# Fleet-level counters derived from monitor= lines (per-host/per-monitor)
if [ -f "$_tmp_mon_snapshot" ]; then
  hosts_ok=$(grep -a -c " status=OK( |$)" "$_tmp_mon_snapshot" 2>/dev/null || echo 0)
  hosts_warn=$(grep -a -c " status=WARN( |$)" "$_tmp_mon_snapshot" 2>/dev/null || echo 0)
  hosts_crit=$(grep -a -c " status=CRIT( |$)" "$_tmp_mon_snapshot" 2>/dev/null || echo 0)
  hosts_unknown=$(grep -a -c " status=UNKNOWN( |$)" "$_tmp_mon_snapshot" 2>/dev/null || echo 0)
  hosts_skip=$(grep -a -c " status=SKIP( |$)" "$_tmp_mon_snapshot" 2>/dev/null || echo 0)
fi


  echo "SUMMARY_HOSTS ok=$hosts_ok warn=$hosts_warn crit=$hosts_crit unknown=$hosts_unknown skipped=$hosts_skip"
  echo ""
  echo "RUNTIME_SUMMARY (per-monitor ms)"
  for m in "${!runtime_ms[@]}"; do
    echo "RUNTIME monitor=$m ms=${runtime_ms[$m]}"
  done
  _tmp_human=$(mktemp -p "$TMPDIR" linux_maint_human.XXXXXX)
{
  echo ""
  echo "HUMAN_STATUS_SUMMARY"
  echo "run_host=$(hostname -f 2>/dev/null || hostname)"
  echo "timestamp=$(lm_now_iso)"
  echo "overall=$overall exit_code=$worst ok=$ok warn=$warn crit=$crit unknown=$unk skipped=$skipped"
  echo "fleet_hosts_ok=$hosts_ok fleet_hosts_warn=$hosts_warn fleet_hosts_crit=$hosts_crit fleet_hosts_unknown=$hosts_unknown fleet_hosts_skipped=$hosts_skip"

  echo ""
  echo "Top CRIT/WARN/UNKNOWN (from monitor= lines)"
  awk '
    {mon="";host="";st="";msg=""}
    {for(i=1;i<=NF;i++){split($i,a,"="); if(a[1]=="monitor")mon=a[2]; if(a[1]=="host")host=a[2]; if(a[1]=="status")st=a[2]; if(a[1]=="msg")msg=a[2];}}
    st=="CRIT" || st=="WARN" || st=="UNKNOWN" {print st ": " host " " mon (msg?" - " msg:"")}
  ' "$_tmp_mon_snapshot" | head -n 50

  echo ""
  echo "Top runtimes (ms)"
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    ms="${line%% *}"
    mon="${line#* }"
    echo "${mon} ms=${ms}"
  done < <(for m in "${!runtime_ms[@]}"; do echo "${runtime_ms[$m]} $m"; done | sort -rn | head -n 10)
  echo ""
  echo "Logs: $logfile"
  echo "Summary: $SUMMARY_FILE"
} > "$_tmp_human"

cat "$_tmp_human" >> "$tmp_report"
# (moved cleanup to after notify so it can include the human+monitor snapshot)
# rm -f "$_tmp_human" "$_tmp_mon_snapshot" 2>/dev/null || true


  # ---- notify (optional, wrapper-level) ----
  # ---- diff since last run (optional, for more actionable notifications) ----
  DIFF_STATE_DIR="${LM_NOTIFY_STATE_DIR:-${LM_STATE_DIR:-/var/lib/linux_maint}}"
  PREV_SUMMARY="$DIFF_STATE_DIR/last_summary_monitor_lines.log"
  CUR_SUMMARY="$_tmp_mon_snapshot"
  DIFF_TEXT=""
  if [[ -f "$PREV_SUMMARY" && -f "$CUR_SUMMARY" && -x "$REPO_DIR/tools/summary_diff.py" ]]; then
    DIFF_TEXT="$(python3 "$REPO_DIR/tools/summary_diff.py" "$PREV_SUMMARY" "$CUR_SUMMARY" 2>/dev/null || true)"
  fi
  # persist current for next run (best-effort)
  mkdir -p "$DIFF_STATE_DIR" 2>/dev/null || true
  cp -f "$CUR_SUMMARY" "$PREV_SUMMARY" 2>/dev/null || true
  if command -v lm_notify_should_send >/dev/null 2>&1; then
    _notify_text="$(cat "$_tmp_human" 2>/dev/null; if [ -n "$DIFF_TEXT" ]; then echo ""; echo "DIFF_SINCE_LAST_RUN"; echo "$DIFF_TEXT"; fi; echo ""; echo "FINAL_STATUS_SUMMARY"; cat "$_tmp_mon_snapshot" 2>/dev/null)"
    if lm_notify_should_send "$_notify_text"; then
      lm_notify_send "health summary overall=$overall" "$_notify_text" || true
      echo "NOTIFY: sent summary email" >> "$tmp_report"
    else
      echo "NOTIFY: skipped" >> "$tmp_report"
    fi
  fi

  # cleanup tmp files created for summaries
  rm -f "$_tmp_human" "$_tmp_mon_snapshot" 2>/dev/null || true


cat "$tmp_report"
set +e
} | awk -v t="$ts_epoch" '{ print strftime("[%F %T]", t), $0 }' | tee "$logfile" >/dev/null
log_rc=$?
set -e
if [[ "$log_rc" -ne 0 || ! -s "$logfile" ]]; then
  echo "WARN: log write failed: $logfile" >> "$tmp_report"
  echo "monitor=wrapper host=runner status=WARN reason=log_write_failed path=$logfile" >> "$tmp_report"
fi

ln -sfn "$logfile" "$LOG_DIR/full_health_monitor_latest.log"

# Write a separate, machine-parseable summary file (optional but enabled by default).
# Contains only "monitor=" lines (no timestamps) so it can be parsed by tools/CI.
mkdir -p "$SUMMARY_DIR" 2>/dev/null || true
tmp_mon=$(mktemp -p "$TMPDIR" linux_maint_mon.XXXXXX)
  grep -a '^monitor=' "$tmp_report" > "$tmp_mon" || true
  cat "$tmp_mon" > "$tmp_summary" 2>/dev/null || :
{ cat "$tmp_summary" > "$SUMMARY_FILE"; } 2>/dev/null || true
if [[ ! -s "$SUMMARY_FILE" ]]; then
  warn_line="monitor=wrapper host=runner status=WARN reason=summary_write_failed path=$SUMMARY_FILE"
  echo "WARN: summary write failed: $SUMMARY_FILE" >> "$tmp_report"
  echo "$warn_line" >> "$tmp_report"
  echo "$warn_line" >> "$tmp_summary"
  { cat "$tmp_summary" > "$SUMMARY_FILE"; } 2>/dev/null || true
  if [[ -s "$logfile" ]]; then
    printf '%s\n' "[WARN] summary write failed: $SUMMARY_FILE" >> "$logfile" 2>/dev/null || true
    printf '%s\n' "$warn_line" >> "$logfile" 2>/dev/null || true
  fi
fi
ln -sfn "$(basename "$SUMMARY_FILE")" "$SUMMARY_LATEST_FILE" 2>/dev/null || true
rm -f "$tmp_summary" 2>/dev/null || true

# Also write JSON + Prometheus outputs (best-effort)
# shellcheck disable=SC2031
SUMMARY_FILE="$SUMMARY_FILE" SUMMARY_JSON_FILE="$SUMMARY_JSON_FILE" SUMMARY_JSON_LATEST_FILE="$SUMMARY_JSON_LATEST_FILE" PROM_FILE="$PROM_FILE" LM_HOSTS_OK="${hosts_ok:-0}" LM_HOSTS_WARN="${hosts_warn:-0}" LM_HOSTS_CRIT="${hosts_crit:-0}" LM_HOSTS_UNKNOWN="${hosts_unknown:-0}" LM_HOSTS_SKIPPED="${hosts_skip:-0}" LM_OVERALL="$overall" LM_EXIT_CODE="$worst" LM_STATUS_FILE="$STATUS_FILE" LM_RUNTIME_FILE="$runtime_file" LM_RUNTIME_WARN_COUNT="$runtime_warn_count" python3 - <<'PY' || true
import json, os
summary_file=os.environ.get("SUMMARY_FILE")
json_file=os.environ.get("SUMMARY_JSON_FILE")
json_latest=os.environ.get("SUMMARY_JSON_LATEST_FILE")
prom_file=os.environ.get("PROM_FILE")
prom_format=os.environ.get("LM_PROM_FORMAT","")
hosts_ok=int(os.environ.get("LM_HOSTS_OK","0"))
hosts_warn=int(os.environ.get("LM_HOSTS_WARN","0"))
hosts_crit=int(os.environ.get("LM_HOSTS_CRIT","0"))
hosts_unknown=int(os.environ.get("LM_HOSTS_UNKNOWN","0"))
hosts_skipped=int(os.environ.get("LM_HOSTS_SKIPPED","0"))
overall=os.environ.get("LM_OVERALL","UNKNOWN")
exit_code=int(os.environ.get("LM_EXIT_CODE","3"))
runtime_file=os.environ.get("LM_RUNTIME_FILE")
runtime_warn_count=int(os.environ.get("LM_RUNTIME_WARN_COUNT","0"))

def parse_kv(line):
    parts=line.strip().split()
    d={}
    for p in parts:
        if "=" in p:
            k,v=p.split("=",1)
            d[k]=v
    return d

rows=[]
if summary_file and os.path.exists(summary_file):
    with open(summary_file,"r",encoding="utf-8",errors="ignore") as f:
        for line in f:
            if line.startswith("monitor="):
                rows.append(parse_kv(line))

# Wrap rows with metadata so consumers can use one stable JSON contract.
# Back-compat: set LM_JSON_LEGACY_LIST=1 to output only the list.
legacy = os.environ.get("LM_JSON_LEGACY_LIST","0") == "1"

def read_status_file(path):
    d={}
    try:
        with open(path,"r",encoding="utf-8",errors="ignore") as f:
            for line in f:
                line=line.strip()
                if not line or "=" not in line: continue
                k,v=line.split("=",1)
                d[k]=v
    except FileNotFoundError:
        pass
    return d

status_file = os.environ.get("LM_STATUS_FILE")
meta = read_status_file(status_file) if status_file else {}

payload = rows if legacy else {"meta": meta, "rows": rows}

if json_file:
    os.makedirs(os.path.dirname(json_file), exist_ok=True)
    with open(json_file,"w",encoding="utf-8") as f:
        json.dump(payload,f,indent=2,sort_keys=True)
    if json_latest:
        try:
            if os.path.islink(json_latest) or os.path.exists(json_latest):
                try: os.unlink(json_latest)
                except: pass
            os.symlink(os.path.basename(json_file),json_latest)
        except: pass

status_map={"OK":0,"WARN":1,"CRIT":2,"UNKNOWN":3,"SKIP":3}

def worst_status(s1, s2):
    """Return the worst of two status strings using the project's exit-code scale."""
    return s1 if status_map.get(s1,3) >= status_map.get(s2,3) else s2

def dedup_rows_worst(rows):
    """Deduplicate monitor+host rows keeping the worst status.

    Some monitors may emit more than one summary line for the same monitor/host
    (e.g. preflight emitting both SKIP and UNKNOWN). Prometheus must not contain
    duplicate labelsets.
    """
    out={}
    for r in rows:
        mon=r.get("monitor","unknown")
        host=r.get("host","all")
        key=(mon,host)
        if key not in out:
            out[key]=r
            continue
        prev=out[key]
        st=worst_status(prev.get("status","UNKNOWN"), r.get("status","UNKNOWN"))
        keep=prev if st==prev.get("status") else r
        # Ensure the kept row has the worst status.
        keep=dict(keep)
        keep["status"]=st
        out[key]=keep
    return list(out.values())
if prom_file and rows:
    try:
        os.makedirs(os.path.dirname(prom_file), exist_ok=True)
        prom_rows = dedup_rows_worst(rows)
        counts={"OK":0,"WARN":0,"CRIT":0,"UNKNOWN":0,"SKIP":0}
        reason_counts={}
        max_reason_labels=20
        try:
            max_reason_labels=max(0, int(os.environ.get("LM_PROM_MAX_REASON_LABELS","20")))
        except Exception:
            max_reason_labels=20
        for r in prom_rows:
            st=r.get("status","UNKNOWN")
            counts[st]=counts.get(st,0)+1
            if st != "OK":
                reason=r.get("reason")
                if reason:
                    reason_counts[reason]=reason_counts.get(reason,0)+1
        with open(prom_file,"w",encoding="utf-8") as f:
            f.write("# HELP linux_maint_monitor_status Monitor status as exit-code scale (OK=0,WARN=1,CRIT=2,UNKNOWN/SKIP=3)\n")
            f.write("# TYPE linux_maint_monitor_status gauge\n")
            f.write("\n# HELP linux_maint_overall_status Overall run status as exit-code scale (OK=0,WARN=1,CRIT=2,UNKNOWN=3)\n")
            f.write("# TYPE linux_maint_overall_status gauge\n")
            f.write(f"linux_maint_overall_status {exit_code}\n")
            f.write("\n# HELP linux_maint_summary_hosts_count Fleet counters derived from monitor= lines\n")
            f.write("# TYPE linux_maint_summary_hosts_count gauge\n")
            f.write(f"linux_maint_summary_hosts_count{{status=\"ok\"}} {hosts_ok}\n")
            f.write(f"linux_maint_summary_hosts_count{{status=\"warn\"}} {hosts_warn}\n")
            f.write(f"linux_maint_summary_hosts_count{{status=\"crit\"}} {hosts_crit}\n")
            f.write(f"linux_maint_summary_hosts_count{{status=\"unknown\"}} {hosts_unknown}\n")
            f.write(f"linux_maint_summary_hosts_count{{status=\"skipped\"}} {hosts_skipped}\n")
            f.write("\n# HELP linux_maint_monitor_status_count Count of monitor results by status (deduped by monitor+host)\n")
            f.write("# TYPE linux_maint_monitor_status_count gauge\n")
            for st in ("OK","WARN","CRIT","UNKNOWN","SKIP"):
                f.write(f"linux_maint_monitor_status_count{{status=\"{st.lower()}\"}} {counts.get(st,0)}\n")

            f.write("\n# HELP linux_maint_reason_count Count of non-OK monitor results by reason token (deduped by monitor+host; top N reasons)\n")
            f.write("# TYPE linux_maint_reason_count gauge\n")
            if reason_counts and max_reason_labels > 0:
                for reason, count in sorted(reason_counts.items(), key=lambda kv: (-kv[1], kv[0]))[:max_reason_labels]:
                    esc_reason=str(reason).replace("\\","\\\\").replace("\"","\\\"")
                    f.write(f"linux_maint_reason_count{{reason=\"{esc_reason}\"}} {count}\n")

            for r in prom_rows:
                mon=r.get("monitor","unknown"); host=r.get("host","all"); st=r.get("status","UNKNOWN")
                val=status_map.get(st,3)
                f.write(f"linux_maint_monitor_status{{monitor=\"{mon}\",host=\"{host}\"}} {val}\n")

            # Runtime metrics (per monitor script)
            if runtime_file:
                f.write("\n# HELP linux_maint_monitor_runtime_ms Monitor runtime in milliseconds (wrapper)\n")
                f.write("# TYPE linux_maint_monitor_runtime_ms gauge\n")
                try:
                    with open(runtime_file,"r",encoding="utf-8",errors="ignore") as rf:
                        for line in rf:
                            if not line.startswith("monitor="):
                                continue
                            parts=line.strip().split()
                            d={}
                            for p in parts:
                                if "=" in p:
                                    k,v=p.split("=",1)
                                    d[k]=v
                            mon=d.get("monitor")
                            ms=d.get("ms")
                            if mon and ms and ms.isdigit():
                                f.write(f"linux_maint_monitor_runtime_ms{{monitor=\"{mon}\"}} {ms}\n")
                except FileNotFoundError:
                    pass

            # Runtime warning count (wrapper guard)
            f.write("\n# HELP linux_maint_runtime_warn_count Count of monitors exceeding runtime warn thresholds\n")
            f.write("# TYPE linux_maint_runtime_warn_count gauge\n")
            f.write(f"linux_maint_runtime_warn_count {runtime_warn_count}\n")
            if prom_format == "openmetrics":
                f.write("# EOF\n")
    except: pass
PY

write_checksum() {
  local path="$1"
  local out="${path}.sha256"
  command -v sha256sum >/dev/null 2>&1 || return 0
  [[ -s "$path" ]] || return 1
  if ! sha256sum "$path" > "$out" 2>/dev/null; then
    return 2
  fi
  return 0
}

checksum_warn() {
  local msg="$1"
  local warn_line="monitor=wrapper host=runner status=WARN reason=summary_checksum_failed msg=$msg"
  echo "WARN: $msg" >> "$tmp_report"
  echo "$warn_line" >> "$tmp_report"
  if [[ -s "$SUMMARY_FILE" ]]; then
    printf '%s\n' "$warn_line" >> "$SUMMARY_FILE" 2>/dev/null || true
  fi
  if [[ -s "$logfile" ]]; then
    printf '%s\n' "[WARN] $msg" >> "$logfile" 2>/dev/null || true
    printf '%s\n' "$warn_line" >> "$logfile" 2>/dev/null || true
  fi
}

if [[ -n "${SUMMARY_FILE:-}" ]]; then
  if ! write_checksum "$SUMMARY_FILE"; then
    checksum_warn "checksum write failed for $SUMMARY_FILE"
  fi
fi
if [[ -n "${SUMMARY_JSON_FILE:-}" && -s "${SUMMARY_JSON_FILE:-}" ]]; then
  if ! write_checksum "$SUMMARY_JSON_FILE"; then
    checksum_warn "checksum write failed for $SUMMARY_JSON_FILE"
  fi
fi

{
  echo "timestamp=$(lm_now_iso)"
  echo "host=$(hostname -f 2>/dev/null || hostname)"
  echo "overall=$overall"
  echo "exit_code=$worst"
  echo "logfile=$logfile"
} > "$STATUS_FILE"
chmod 0644 "$STATUS_FILE"

rm -f "$tmp_report" "$runtime_file" 2>/dev/null || true

exit "$worst"
