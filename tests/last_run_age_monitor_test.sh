#!/usr/bin/env bash
set -euo pipefail

TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
MON="$ROOT_DIR/monitors/last_run_age_monitor.sh"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

logdir="$workdir/logs"
mkdir -p "$logdir"

run_case() {
  local label="$1"; shift
  local expect="$1"; shift
  out="$(env LM_LAST_RUN_LOG_DIR="$logdir" LM_LAST_RUN_MAX_AGE_MIN=1 LM_LOCKDIR="$workdir" LM_LOGFILE="$workdir/last_run.log" "$@" bash "$MON")"
  echo "$out" | grep -q "$expect" || { echo "FAIL: $label: $out" >&2; exit 1; }
}

run_case "missing log" "reason=missing_last_run_log"

latest="$logdir/full_health_monitor_latest.log"
: > "$latest"
LOG_PATH="$latest" python3 - <<PY
import os, time
path = os.environ["LOG_PATH"]
old = time.time() - 600
os.utime(path, (old, old))
PY
run_case "stale log" "reason=stale_run"

: > "$latest"
run_case "fresh log" "status=OK" LM_LAST_RUN_MAX_AGE_MIN=10

echo "last run age monitor ok"
