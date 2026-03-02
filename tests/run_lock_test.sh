#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v flock >/dev/null 2>&1; then
  echo "flock not available; skipping run lock test"
  exit 0
fi

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

state_dir="$workdir/state"
cfg_dir="$workdir/etc"
log_dir="$workdir/logs"
summary_dir="$workdir/summary"
mkdir -p "$state_dir" "$cfg_dir" "$log_dir" "$summary_dir"
printf '%s\n' localhost > "$cfg_dir/servers.txt"
: > "$cfg_dir/excluded.txt"

lock_file="$state_dir/linux_maint_run.lock"

( exec 9>"$lock_file"; flock -n 9; sleep 3 ) &
locker_pid=$!
sleep 0.2

set +e
out="$(LM_RUN_LOCK_TIMEOUT=1 LM_STATE_DIR="$state_dir" LOG_DIR="$log_dir" SUMMARY_DIR="$summary_dir" LM_CFG_DIR="$cfg_dir" LM_MONITORS="health_monitor.sh" LM_TEST_MODE=1 bash "$ROOT_DIR/run_full_health_monitor.sh" 2>&1)"
rc=$?
set -e

kill "$locker_pid" 2>/dev/null || true
wait "$locker_pid" 2>/dev/null || true

if [[ "$rc" -ne 2 ]]; then
  echo "expected rc=2 when lock held, got rc=$rc" >&2
  echo "$out" >&2
  exit 1
fi
printf '%s\n' "$out" | grep -q 'already in progress' || {
  echo "expected lock contention message" >&2
  echo "$out" >&2
  exit 1
}

echo "run lock test ok"
