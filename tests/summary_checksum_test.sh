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
summary_file="$summary_dir/full_health_monitor_summary_${stamp}.log"
summary_json="$summary_dir/full_health_monitor_summary_${stamp}.json"

LM_MONITORS="health_monitor.sh" \
LM_TEST_TIME_EPOCH="$epoch" \
LM_CFG_DIR="$cfg" \
LM_SERVERLIST="$cfg/servers.txt" \
LM_EXCLUDED="$cfg/excluded.txt" \
LOG_DIR="$log_dir" \
SUMMARY_DIR="$summary_dir" \
LM_LOCAL_ONLY=true \
bash "$ROOT_DIR/run_full_health_monitor.sh" >/dev/null || true

[[ -f "${summary_file}.sha256" ]]
[[ -f "${summary_json}.sha256" ]]

sha_line="$(cat "${summary_file}.sha256")"
expected="$(sha256sum "$summary_file" | awk '{print $1}')"
echo "$sha_line" | grep -q "$expected"

echo "summary checksum ok"
