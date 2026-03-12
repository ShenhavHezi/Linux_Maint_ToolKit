#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
workdir="$(mktemp -d "${TMPDIR:-/tmp}/lm_wrapper_cfg.XXXXXX")"
cleanup(){ rm -rf "$workdir"; }
trap cleanup EXIT

cfg="$workdir/cfg"
log_dir="$workdir/logs"
summary_dir="$workdir/summary"
state_dir="$workdir/state"
mkdir -p "$cfg" "$log_dir" "$summary_dir" "$state_dir"

printf '%s\n' localhost > "$cfg/servers.txt"
: > "$cfg/excluded.txt"
printf '%s\n' '127.0.0.1:1' > "$cfg/certs.txt"

LM_TEST_MODE=1 \
LM_CFG_DIR_FALLBACK="$cfg" \
LOG_DIR="$log_dir" \
SUMMARY_DIR="$summary_dir" \
LM_STATE_DIR="$state_dir" \
LM_MONITORS="cert_monitor.sh" \
LM_CERT_TIMEOUT_SECS=1 \
bash "$ROOT_DIR/run_full_health_monitor.sh" >/dev/null 2>&1 || true

log_file="$(find "$log_dir" -maxdepth 1 -type f -name 'full_health_monitor_*.log' ! -name '*latest*' | sort | head -n 1)"
summary_file="$(find "$summary_dir" -maxdepth 1 -type f -name 'full_health_monitor_summary_*.log' ! -name '*latest*' | sort | head -n 1)"

if [ -z "$log_file" ] || [ -z "$summary_file" ]; then
  echo "wrapper artifacts missing" >&2
  find "$workdir" -maxdepth 3 -type f | sort >&2 || true
  exit 1
fi

grep -q '^monitor=cert_monitor ' "$summary_file" || {
  echo "missing cert_monitor summary" >&2
  cat "$log_file" >&2 || true
  exit 1
}

if grep -q 'Targets file not found/empty: /etc/linux_maint/certs.txt' "$log_file"; then
  echo "cert_monitor ignored wrapper fallback config dir" >&2
  cat "$log_file" >&2
  exit 1
fi

echo "wrapper cfg dir fallback cert monitor ok"
