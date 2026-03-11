#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
workdir="$(mktemp -d "${TMPDIR:-/tmp}/lm_wrapper_summary_latest.XXXXXX")"
cleanup(){ rm -rf "$workdir"; }
trap cleanup EXIT

cfg="$workdir/cfg"
log_dir="$workdir/logs"
summary_dir="$workdir/summary"
latest_dir="$workdir/latest"
state_dir="$workdir/state"
mkdir -p "$cfg" "$log_dir" "$summary_dir" "$latest_dir" "$state_dir"

printf '%s\n' localhost > "$cfg/servers.txt"
: > "$cfg/excluded.txt"

LM_TEST_MODE=1 \
LM_CFG_DIR="$cfg" \
LOG_DIR="$log_dir" \
SUMMARY_DIR="$summary_dir" \
SUMMARY_LATEST_FILE="$latest_dir/full_health_monitor_summary_latest.log" \
SUMMARY_JSON_LATEST_FILE="$latest_dir/full_health_monitor_summary_latest.json" \
LM_STATE_DIR="$state_dir" \
LM_MONITORS="health_monitor.sh" \
bash "$ROOT_DIR/run_full_health_monitor.sh" >/dev/null 2>&1 || true

latest_log="$latest_dir/full_health_monitor_summary_latest.log"
latest_json="$latest_dir/full_health_monitor_summary_latest.json"

[[ -L "$latest_log" && -e "$latest_log" ]] || {
  echo "summary latest log symlink should resolve across directories" >&2
  ls -l "$latest_dir" >&2 || true
  exit 1
}

[[ -L "$latest_json" && -e "$latest_json" ]] || {
  echo "summary latest json symlink should resolve across directories" >&2
  ls -l "$latest_dir" >&2 || true
  exit 1
}

grep -q '^monitor=health_monitor ' "$latest_log" || {
  echo "summary latest override log content missing health monitor line" >&2
  cat "$latest_log" >&2 || true
  exit 1
}

python3 - <<'PY' "$latest_json"
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as f:
    obj = json.load(f)

assert obj["schema_version"] == 1
assert any(row.get("monitor") == "health_monitor" for row in obj["rows"])
PY

echo "wrapper summary latest override ok"
