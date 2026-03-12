#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
workdir="$(mktemp -d "${TMPDIR:-/tmp}/lm_wrapper_log.XXXXXX")"
cleanup(){ rm -rf "$workdir"; }
trap cleanup EXIT

cfg="$workdir/cfg"
log_dir="$workdir/logs"
summary_dir="$workdir/summary"
state_dir="$workdir/state"
mkdir -p "$cfg" "$log_dir" "$summary_dir" "$state_dir"

printf '%s\n' localhost > "$cfg/servers.txt"
: > "$cfg/excluded.txt"

unset LM_LOGFILE
LM_TEST_MODE=1 \
LM_CFG_DIR="$cfg" \
LOG_DIR="$log_dir" \
SUMMARY_DIR="$summary_dir" \
LM_STATE_DIR="$state_dir" \
LM_MONITORS="health_monitor.sh" \
bash "$ROOT_DIR/run_full_health_monitor.sh" >/dev/null 2>&1 || true

log_file="$(find "$log_dir" -maxdepth 1 -type f -name 'full_health_monitor_*.log' ! -name '*latest*' | sort | head -n 1)"
summary_file="$(find "$summary_dir" -maxdepth 1 -type f -name 'full_health_monitor_summary_*.log' ! -name '*latest*' | sort | head -n 1)"

if [ -z "$log_file" ] || [ -z "$summary_file" ]; then
  echo "wrapper artifacts missing" >&2
  find "$workdir" -maxdepth 3 -type f | sort >&2 || true
  exit 1
fi

grep -q '^monitor=health_monitor ' "$summary_file" || {
  echo "missing health_monitor summary" >&2
  cat "$log_file" >&2 || true
  exit 1
}

if grep -q 'Permission denied' "$log_file"; then
  echo "wrapper still hit permission denied for default logfile" >&2
  cat "$log_file" >&2
  exit 1
fi

if grep -q '/var/log/linux_maint.log' "$log_file"; then
  echo "wrapper still used /var/log/linux_maint.log in repo mode" >&2
  cat "$log_file" >&2
  exit 1
fi

echo "wrapper repo logfile default ok"
