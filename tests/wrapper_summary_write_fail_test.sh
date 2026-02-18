#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

cfg="$workdir/etc_linux_maint"
log_dir="$workdir/logs"
summary_dir="$workdir/summary"
mkdir -p "$cfg" "$log_dir" "$summary_dir"
printf '%s\n' localhost > "$cfg/servers.txt"
: > "$cfg/excluded.txt"

epoch=1700000000
stamp="$(date -d "@$epoch" +%F_%H%M%S)"
expected_log="$log_dir/full_health_monitor_${stamp}.log"

LM_MONITORS="health_monitor.sh" \
LM_TEST_TIME_EPOCH="$epoch" \
LM_CFG_DIR="$cfg" \
LM_SERVERLIST="$cfg/servers.txt" \
LM_EXCLUDED="$cfg/excluded.txt" \
LOG_DIR="$log_dir" \
SUMMARY_DIR="$summary_dir" \
SUMMARY_FILE="/root/deny/summary_${stamp}.log" \
LM_LOCAL_ONLY=true \
bash "$ROOT_DIR/run_full_health_monitor.sh" >/dev/null || true

if [[ ! -f "$expected_log" ]]; then
  echo "FAIL: expected log not found: $expected_log" >&2
  exit 1
fi

grep -q "summary_write_failed" "$expected_log"

first_ts="$(head -n 1 "$expected_log" | awk '{print $1,$2}')"
expected_ts="[$(date -d "@$epoch" "+%F %T")]"
if [[ "$first_ts" != "$expected_ts" ]]; then
  echo "FAIL: timestamp mismatch: got $first_ts expected $expected_ts" >&2
  exit 1
fi

echo "wrapper summary write fail ok"
