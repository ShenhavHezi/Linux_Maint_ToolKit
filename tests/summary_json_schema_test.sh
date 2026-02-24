#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

cfg="$workdir/etc_linux_maint"
log_dir="$workdir/logs"
summary_dir="$workdir/summary"
state_dir="$workdir/state"
mkdir -p "$cfg" "$log_dir" "$summary_dir" "$state_dir"
printf '%s\n' localhost > "$cfg/servers.txt"
: > "$cfg/excluded.txt"

# Generate a summary JSON using the wrapper (minimal monitor set).
LM_MONITORS="health_monitor.sh" \
LM_TEST_MODE=1 \
LM_CFG_DIR="$cfg" \
LM_SERVERLIST="$cfg/servers.txt" \
LM_EXCLUDED="$cfg/excluded.txt" \
LOG_DIR="$log_dir" \
SUMMARY_DIR="$summary_dir" \
LM_STATE_DIR="$state_dir" \
LM_LOCAL_ONLY=true \
bash "$ROOT_DIR/run_full_health_monitor.sh" >/dev/null 2>&1 || true

summary_json="$summary_dir/full_health_monitor_summary_latest.json"
if [[ ! -s "$summary_json" ]]; then
  echo "missing summary json: $summary_json" >&2
  exit 1
fi

python3 "$ROOT_DIR/tools/json_schema_validate.py" "$ROOT_DIR/docs/schemas/summary.json" < "$summary_json"

echo "summary json schema ok"
