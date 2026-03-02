#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WRAP="$ROOT_DIR/run_full_health_monitor.sh"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

state_dir="$workdir/state"
cfg_dir="$workdir/etc"
log_dir="$workdir/logs"
summary_dir="$workdir/summary"
mkdir -p "$state_dir" "$cfg_dir" "$log_dir" "$summary_dir"

printf '%s\n' localhost > "$cfg_dir/servers.txt"
: > "$cfg_dir/excluded.txt"
: > "$cfg_dir/services.txt"

LM_TEST_MODE=1 LM_HISTORY_SQLITE=1 LM_HISTORY_DB="$state_dir/run_index.sqlite" LM_STATE_DIR="$state_dir" LM_CFG_DIR="$cfg_dir" LOG_DIR="$log_dir" SUMMARY_DIR="$summary_dir" LM_MONITORS="health_monitor.sh" bash "$WRAP" >/dev/null 2>&1 || true

[[ -f "$state_dir/run_index.sqlite" ]] || {
  echo "sqlite index not created" >&2
  exit 1
}

json_out="$(LM_HISTORY_SQLITE=1 LM_HISTORY_DB="$state_dir/run_index.sqlite" LM_STATE_DIR="$state_dir" bash "$LM" history --sqlite --json --last 1 2>/dev/null || true)"
printf '%s\n' "$json_out" | grep -q '"runs"' || {
  echo "history sqlite json missing runs" >&2
  echo "$json_out" >&2
  exit 1
}

echo "history sqlite ok"
