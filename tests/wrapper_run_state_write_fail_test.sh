#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
workdir="$(mktemp -d "${TMPDIR:-/tmp}/lm_wrapper_run_state_fail.XXXXXX")"
cleanup(){ rm -rf "$workdir"; }
trap cleanup EXIT

cfg="$workdir/cfg"
log_dir="$workdir/logs"
summary_dir="$workdir/summary"
state_dir="$workdir/state"
run_id="run-state-fail-001"
mkdir -p "$cfg" "$log_dir" "$summary_dir" "$state_dir"

printf '%s\n' localhost > "$cfg/servers.txt"
: > "$cfg/excluded.txt"

mkdir -p "$state_dir/run_state_${run_id}.log"

LM_TEST_MODE=1 \
LM_RUN_ID="$run_id" \
LM_CFG_DIR="$cfg" \
LOG_DIR="$log_dir" \
SUMMARY_DIR="$summary_dir" \
LM_STATE_DIR="$state_dir" \
LM_MONITORS="health_monitor.sh" \
bash "$ROOT_DIR/run_full_health_monitor.sh" >/dev/null 2>&1 || true

latest_log="$(find "$log_dir" -maxdepth 1 -type f -name 'full_health_monitor_*.log' ! -name '*latest*' | sort | head -n 1)"
summary_file="$(find "$summary_dir" -maxdepth 1 -type f -name 'full_health_monitor_summary_*.log' ! -name '*latest*' | sort | head -n 1)"

[[ -n "$latest_log" && -n "$summary_file" ]] || {
  echo "wrapper artifacts missing after run-state write failure" >&2
  find "$workdir" -maxdepth 3 \( -type f -o -type d \) | sort >&2 || true
  exit 1
}

grep -q 'run_state_write_failed' "$latest_log" || {
  echo "expected run_state_write_failed warning in logfile" >&2
  cat "$latest_log" >&2
  exit 1
}

grep -q 'run_state_write_failed' "$summary_file" || {
  echo "expected run_state_write_failed warning in summary file" >&2
  cat "$summary_file" >&2
  exit 1
}

[[ -d "$state_dir/run_state_${run_id}.log" ]] || {
  echo "run-state failure fixture should remain a directory" >&2
  ls -ld "$state_dir/run_state_${run_id}.log" >&2 || true
  exit 1
}

echo "wrapper run state write fail ok"
