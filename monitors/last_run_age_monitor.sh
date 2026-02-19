#!/usr/bin/env bash
set -euo pipefail

# Ensure the wrapper has run recently (based on latest log mtime).
. "${LINUX_MAINT_LIB:-/usr/local/lib/linux_maint.sh}" || { echo "Missing ${LINUX_MAINT_LIB:-/usr/local/lib/linux_maint.sh}"; exit 1; }
LM_PREFIX="[last_run_age_monitor] "
LM_LOGFILE="${LM_LOGFILE:-/var/log/last_run_age_monitor.log}"

lm_require_singleton "last_run_age_monitor"

MAX_AGE_MIN="${LM_LAST_RUN_MAX_AGE_MIN:-120}"
LOG_DIR="${LM_LAST_RUN_LOG_DIR:-/var/log/health}"

if [[ ! "$MAX_AGE_MIN" =~ ^[0-9]+$ ]]; then
  lm_summary "last_run_age_monitor" "runner" "UNKNOWN" reason=config_invalid max_age_min="$MAX_AGE_MIN"
  exit 3
fi

latest=""
if [[ -f "$LOG_DIR/full_health_monitor_latest.log" ]]; then
  latest="$LOG_DIR/full_health_monitor_latest.log"
elif [[ -d "$LOG_DIR" ]]; then
  # shellcheck disable=SC2012
  latest="$(ls -1t "$LOG_DIR"/full_health_monitor_*.log 2>/dev/null | head -n 1 || true)"
fi

if [[ -z "$latest" || ! -e "$latest" ]]; then
  lm_summary "last_run_age_monitor" "runner" "WARN" reason=missing_last_run_log log_dir="$LOG_DIR"
  exit 0
fi

mtime=""
if stat -c %Y "$latest" >/dev/null 2>&1; then
  mtime="$(stat -c %Y "$latest" 2>/dev/null || true)"
else
  mtime="$(python3 - <<PY
import os,sys
print(int(os.path.getmtime(sys.argv[1])))
PY
"$latest" 2>/dev/null || true)"
fi

now="$(date +%s)"
if [[ ! "$mtime" =~ ^[0-9]+$ ]]; then
  lm_summary "last_run_age_monitor" "runner" "UNKNOWN" reason=collect_failed path="$latest"
  exit 3
fi

age_min=$(( (now - mtime) / 60 ))
if [[ "$age_min" -gt "$MAX_AGE_MIN" ]]; then
  lm_summary "last_run_age_monitor" "runner" "WARN" reason=stale_run age_min="$age_min" max_age_min="$MAX_AGE_MIN" path="$latest"
  exit 0
fi

lm_summary "last_run_age_monitor" "runner" "OK" age_min="$age_min" max_age_min="$MAX_AGE_MIN" path="$latest"
exit 0
