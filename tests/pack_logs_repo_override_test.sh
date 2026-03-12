#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

logdir="$workdir/logs"
summarydir="$workdir/summary"
cfgdir="$workdir/etc_linux_maint"
statedir="$workdir/state"
outdir="$workdir/out"
mkdir -p "$logdir" "$summarydir" "$cfgdir" "$statedir" "$outdir"

printf '%s\n' 'custom-log-marker' > "$logdir/full_health_monitor_latest.log"
printf '%s\n' 'monitor=fake host=localhost status=OK node=test summary-source=override' > "$summarydir/full_health_monitor_summary_latest.log"
printf '%s\n' '{"rows":[],"source":"override"}' > "$summarydir/full_health_monitor_summary_latest.json"
printf '%s\n' 'overall=OK' > "$logdir/last_status_full"
printf '%s\n' localhost > "$cfgdir/servers.txt"
printf '%s\n' 'custom-state-marker' > "$statedir/run_index.jsonl"

bundle_path="$(
  LM_PROGRESS=0 \
  LOG_DIR="$logdir" \
  SUMMARY_DIR="$summarydir" \
  LM_STATE_DIR="$statedir" \
  LM_CFG_DIR="$cfgdir" \
  "$LM" pack-logs --out "$outdir"
)"

[[ -f "$bundle_path" ]] || {
  echo "pack-logs did not create bundle" >&2
  exit 1
}

tar -xOf "$bundle_path" ./logs/full_health_monitor_latest.log | grep -q '^custom-log-marker$' || {
  echo "pack-logs ignored repo LOG_DIR override" >&2
  exit 1
}

tar -xOf "$bundle_path" ./state/run_index.jsonl | grep -q '^custom-state-marker$' || {
  echo "pack-logs ignored repo state override" >&2
  exit 1
}

tar -xOf "$bundle_path" ./logs/full_health_monitor_summary_latest.log | grep -q 'summary-source=override' || {
  echo "pack-logs ignored repo SUMMARY_DIR override for summary log" >&2
  exit 1
}

tar -xOf "$bundle_path" ./logs/full_health_monitor_summary_latest.json | grep -q '"source":"override"' || {
  echo "pack-logs ignored repo SUMMARY_DIR override for summary json" >&2
  exit 1
}

echo "pack-logs repo override ok"
