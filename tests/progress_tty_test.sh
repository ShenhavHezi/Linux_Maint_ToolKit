#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

log_dir="$tmp_root/logs"
cfg_dir="$tmp_root/cfg"
state_dir="$tmp_root/state"
out_dir="$tmp_root/out"
mkdir -p "$log_dir" "$cfg_dir" "$state_dir" "$out_dir"

# Create a dummy log to ensure pack-logs has content to process
echo "dummy" > "$log_dir/full_health_monitor_latest.log"

err_file="$tmp_root/err.txt"

LM_PROGRESS=1 LOG_DIR="$log_dir" CFG_DIR="$cfg_dir" STATE_DIR="$state_dir" OUTDIR="$out_dir" \
  bash "$ROOT_DIR/tools/pack_logs.sh" 2> "$err_file" >/dev/null

if [[ -s "$err_file" ]]; then
  echo "expected no progress output on non-TTY stderr" >&2
  sed -n '1,50p' "$err_file" >&2 || true
  exit 1
fi

echo "progress tty suppression ok"
