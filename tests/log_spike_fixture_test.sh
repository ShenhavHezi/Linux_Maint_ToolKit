#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

run_case() {
  local fixture="$1" warn="$2" crit="$3" exp_status="$4"
  out="$({
    LINUX_MAINT_LIB="$ROOT_DIR/lib/linux_maint.sh" \
    LM_LOCKDIR=/tmp \
    LM_LOGFILE=/tmp/linux_maint_log_spike_test.log \
    LM_LOG_SPIKE_SOURCE=file \
    LM_LOG_SPIKE_FIXTURE_FILE="$ROOT_DIR/tests/fixtures/$fixture" \
    LM_LOG_SPIKE_WARN="$warn" \
    LM_LOG_SPIKE_CRIT="$crit" \
    bash "$ROOT_DIR/monitors/log_spike_monitor.sh"
  } 2>/dev/null)"

  echo "$out" | grep -q '^monitor=log_spike_monitor ' || { echo "missing summary" >&2; echo "$out" >&2; exit 1; }
  status="$(echo "$out" | awk '{for(i=1;i<=NF;i++){split($i,a,"="); if(a[1]=="status"){print a[2]; exit}}}')"
  [ "$status" = "$exp_status" ] || { echo "expected $exp_status got $status" >&2; echo "$out" >&2; exit 1; }
}

run_case log_spike_ok.log 2 4 OK
run_case log_spike_warn.log 2 4 WARN
run_case log_spike_warn.log 1 2 CRIT

echo "log_spike fixture ok"
