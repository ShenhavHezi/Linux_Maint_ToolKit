#!/usr/bin/env bash
set -euo pipefail

# Log spike monitor (kernel/service errors rate)
# Best-effort sources: journald (journalctl) or syslog/messages file.

. "${LINUX_MAINT_LIB:-/usr/local/lib/linux_maint.sh}" || { echo "Missing ${LINUX_MAINT_LIB:-/usr/local/lib/linux_maint.sh}"; exit 1; }
LM_PREFIX="[log_spike_monitor] "
LM_LOGFILE="${LM_LOGFILE:-/var/log/log_spike_monitor.log}"

lm_require_singleton "log_spike_monitor"

: "${LM_LOG_SPIKE_WINDOW_MIN:=60}"
: "${LM_LOG_SPIKE_WARN:=50}"
: "${LM_LOG_SPIKE_CRIT:=200}"
: "${LM_LOG_SPIKE_SOURCE:=auto}" # auto|journal|syslog|messages|file

# For tests: point at a fixture file and use LM_LOG_SPIKE_SOURCE=file.
: "${LM_LOG_SPIKE_FIXTURE_FILE:=}"

# Simple, conservative pattern for error-ish lines.
# - kernel: panic, oops, segfault, OOM
# - generic: error, failed
: "${LM_LOG_SPIKE_PATTERN:=panic|oops|segfault|out of memory|oom|error|failed}"
pattern_token="$(printf '%s' "$LM_LOG_SPIKE_PATTERN" | tr -s '[:space:]' '_' )"

is_int() { [[ "${1:-}" =~ ^[0-9]+$ ]]; }

if ! is_int "$LM_LOG_SPIKE_WINDOW_MIN" || [ "$LM_LOG_SPIKE_WINDOW_MIN" -le 0 ]; then
  lm_summary "log_spike_monitor" "localhost" "UNKNOWN" reason=config_invalid window_min="$LM_LOG_SPIKE_WINDOW_MIN"
  exit 3
fi

if ! is_int "$LM_LOG_SPIKE_WARN" || ! is_int "$LM_LOG_SPIKE_CRIT"; then
  lm_summary "log_spike_monitor" "localhost" "UNKNOWN" reason=config_invalid warn="$LM_LOG_SPIKE_WARN" crit="$LM_LOG_SPIKE_CRIT"
  exit 3
fi

# Determine source
source=""
get_lines() {
  case "$1" in
    file)
      [ -n "$LM_LOG_SPIKE_FIXTURE_FILE" ] || return 2
      [ -r "$LM_LOG_SPIKE_FIXTURE_FILE" ] || return 3
      cat "$LM_LOG_SPIKE_FIXTURE_FILE"
      ;;
    journal)
      lm_require_cmd "log_spike_monitor" "localhost" journalctl --optional || true
      if ! lm_has_cmd journalctl; then
        return 4
      fi
      # Best-effort: last window minutes, no pager
      journalctl --no-pager -S "${LM_LOG_SPIKE_WINDOW_MIN} min ago" 2>/dev/null || return 5
      ;;
    syslog)
      [ -r /var/log/syslog ] || return 6
      # No reliable timestamps across distros without date parsing; use tail window.
      tail -n 5000 /var/log/syslog 2>/dev/null || return 7
      ;;
    messages)
      [ -r /var/log/messages ] || return 8
      tail -n 5000 /var/log/messages 2>/dev/null || return 9
      ;;
    *)
      return 10
      ;;
  esac
}

pick_source() {
  case "$LM_LOG_SPIKE_SOURCE" in
    file)
      source="file"; return 0;;
    journal)
      source="journal"; return 0;;
    syslog)
      source="syslog"; return 0;;
    messages)
      source="messages"; return 0;;
    auto)
      if lm_has_cmd journalctl; then source="journal"; return 0; fi
      if [ -r /var/log/syslog ]; then source="syslog"; return 0; fi
      if [ -r /var/log/messages ]; then source="messages"; return 0; fi
      return 1
      ;;
    *)
      return 1
      ;;
  esac
}

if ! pick_source; then
  lm_summary "log_spike_monitor" "localhost" "SKIP" reason=missing_log_source source="$LM_LOG_SPIKE_SOURCE"
  exit 0
fi

# Count matching lines
lines=""
if ! lines="$(get_lines "$source" 2>/dev/null)"; then
  # If we failed to read chosen source, degrade to UNKNOWN (not CRIT; avoid noisy alerts).
  lm_summary "log_spike_monitor" "localhost" "UNKNOWN" reason=permission_denied source="$source"
  exit 3
fi

errors=$(
  # grep exits 1 when there are 0 matches; under `set -e` that would
  # incorrectly abort the monitor. Treat 0 matches as a valid OK result.
  printf %s "${lines}" | grep -Eaci "$LM_LOG_SPIKE_PATTERN" || true
)
errors=$(printf %s "$errors" | tr -d "[:space:]")
errors=${errors:-0}

status="OK"
reason=""
if [ "$errors" -ge "$LM_LOG_SPIKE_CRIT" ]; then
  status="CRIT"; reason="log_spike_crit"
elif [ "$errors" -ge "$LM_LOG_SPIKE_WARN" ]; then
  status="WARN"; reason="log_spike_warn"
fi

if [ "$status" = "OK" ]; then
  lm_summary "log_spike_monitor" "localhost" "$status" source="$source" errors="$errors" window_min="$LM_LOG_SPIKE_WINDOW_MIN" pattern="$pattern_token"
  exit 0
fi

lm_summary "log_spike_monitor" "localhost" "$status" reason="$reason" source="$source" errors="$errors" window_min="$LM_LOG_SPIKE_WINDOW_MIN" pattern="$pattern_token"
exit 0
