#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WRAP="$ROOT_DIR/run_full_health_monitor.sh"

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

lock_meta="$state_dir/linux_maint_run.lock.meta"
cat > "$lock_meta" <<'M'
pid=999999
run_id=stale
started=2026-03-02T00:00:00Z
M

LM_TEST_MODE=1 LM_STATE_DIR="$state_dir" LM_CFG_DIR="$cfg_dir" LOG_DIR="$log_dir" SUMMARY_DIR="$summary_dir" LM_MONITORS="health_monitor.sh" bash "$WRAP" >/dev/null 2>&1 || true

[[ ! -f "$lock_meta" ]] || {
  echo "stale lock meta was not cleaned" >&2
  cat "$lock_meta" >&2
  exit 1
}

echo "run stale lock meta ok"
