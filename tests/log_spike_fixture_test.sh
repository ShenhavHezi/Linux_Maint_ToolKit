#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
workdir="$(mktemp -d "${TMPDIR%/}/log_spike_fixture.XXXXXX")"
trap 'rm -rf "$workdir"' EXIT

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

run_case() {
  local fixture="$1" warn="$2" crit="$3" exp_status="$4"
  set +e
  out="$({
    LINUX_MAINT_LIB="$ROOT_DIR/lib/linux_maint.sh" \
    LM_LOCKDIR="${workdir}" \
    LM_LOGFILE="${workdir}/linux_maint_log_spike_test.log" \
    LM_LOG_SPIKE_SOURCE=file \
    LM_LOG_SPIKE_FIXTURE_FILE="$ROOT_DIR/tests/fixtures/$fixture" \
    LM_LOG_SPIKE_WARN="$warn" \
    LM_LOG_SPIKE_CRIT="$crit" \
    LM_LOG_SPIKE_PATTERN='error|failed|oom' \
    bash "$ROOT_DIR/monitors/log_spike_monitor.sh"
  } 2>&1)"
  rc=$?
  set -e

  summary_line="$(printf '%s\n' "$out" | grep '^monitor=log_spike_monitor ' | tail -n 1)"
  if [[ -z "$summary_line" ]]; then
    echo "missing summary (rc=$rc)" >&2
    echo "$out" >&2
    exit 1
  fi
  status="$(printf '%s\n' "$summary_line" | awk '{for(i=1;i<=NF;i++){split($i,a,"="); if(a[1]=="status"){print a[2]; exit}}}')"
  if [[ "$status" != "$exp_status" ]]; then
    echo "expected $exp_status got $status (rc=$rc)" >&2
    echo "$out" >&2
    exit 1
  fi
}

run_case log_spike_ok.log 2 4 OK
run_case log_spike_warn.log 2 4 WARN
run_case log_spike_warn.log 1 2 CRIT

echo "log_spike fixture ok"
