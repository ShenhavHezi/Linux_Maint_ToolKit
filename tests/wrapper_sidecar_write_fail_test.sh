#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
workdir="$(mktemp -d "${TMPDIR:-/tmp}/lm_wrapper_sidecar_fail.XXXXXX")"
cleanup(){ rm -rf "$workdir"; }
trap cleanup EXIT

cfg="$workdir/cfg"
log_dir="$workdir/logs"
summary_dir="$workdir/summary"
state_dir="$workdir/state"
stamp="2000-01-01_020000"
json_path="$summary_dir/full_health_monitor_summary_${stamp}.json"
prom_path="$workdir/prom/linux_maint.prom"
mkdir -p "$cfg" "$log_dir" "$summary_dir" "$state_dir" "$workdir/prom"

printf '%s\n' localhost > "$cfg/servers.txt"
: > "$cfg/excluded.txt"

mkdir -p "$json_path"
mkdir -p "$prom_path"

LM_TEST_MODE=1 \
LM_CFG_DIR="$cfg" \
LOG_DIR="$log_dir" \
SUMMARY_DIR="$summary_dir" \
SUMMARY_JSON_FILE="$json_path" \
PROM_FILE="$prom_path" \
LM_STATE_DIR="$state_dir" \
LM_MONITORS="health_monitor.sh" \
bash "$ROOT_DIR/run_full_health_monitor.sh" >/dev/null 2>&1 || true

latest_log="$(find "$log_dir" -maxdepth 1 -type f -name 'full_health_monitor_*.log' ! -name '*latest*' | sort | head -n 1)"
summary_file="$(find "$summary_dir" -maxdepth 1 -type f -name 'full_health_monitor_summary_*.log' ! -name '*latest*' | sort | head -n 1)"

[[ -n "$latest_log" && -n "$summary_file" ]] || {
  echo "wrapper artifacts missing after sidecar failure" >&2
  find "$workdir" -maxdepth 4 \( -type f -o -type d \) | sort >&2 || true
  exit 1
}

grep -q 'summary_json_write_failed' "$latest_log" || {
  echo "expected summary_json_write_failed warning in logfile" >&2
  cat "$latest_log" >&2
  exit 1
}

grep -q 'prom_write_failed' "$latest_log" || {
  echo "expected prom_write_failed warning in logfile" >&2
  cat "$latest_log" >&2
  exit 1
}

grep -q 'summary_json_write_failed' "$summary_file" || {
  echo "expected summary_json_write_failed warning in summary file" >&2
  cat "$summary_file" >&2
  exit 1
}

grep -q 'prom_write_failed' "$summary_file" || {
  echo "expected prom_write_failed warning in summary file" >&2
  cat "$summary_file" >&2
  exit 1
}

find "$summary_dir" -maxdepth 1 -type f -name '.summary_json.*' | grep -q . && {
  echo "summary json temp file leaked after failure" >&2
  find "$summary_dir" -maxdepth 1 -type f -name '.summary_json.*' -print >&2
  exit 1
}

find "$workdir/prom" -maxdepth 1 -type f -name '.linux_maint_prom.*' | grep -q . && {
  echo "prom temp file leaked after failure" >&2
  find "$workdir/prom" -maxdepth 1 -type f -name '.linux_maint_prom.*' -print >&2
  exit 1
}

[[ -d "$json_path" && -d "$prom_path" ]] || {
  echo "sidecar failure fixtures should remain directories" >&2
  ls -ld "$json_path" "$prom_path" >&2 || true
  exit 1
}

echo "wrapper sidecar write fail ok"
