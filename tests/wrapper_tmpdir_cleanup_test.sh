#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

cfg_dir="$workdir/etc"
mkdir -p "$cfg_dir"

echo "localhost" > "$cfg_dir/servers.txt"
: > "$cfg_dir/excluded.txt"
: > "$cfg_dir/services.txt"

TMPDIR="$workdir/tmp" \
LM_CFG_DIR="$cfg_dir" \
LM_STATE_DIR="$workdir/state" \
LM_LOG_DIR="$workdir/logs" \
LM_TEST_MODE=1 \
LM_MONITORS="preflight_check.sh" \
LM_NOTIFY=0 \
LM_EMAIL_ENABLED=false \
LM_PROGRESS=0 \
bash "$ROOT_DIR/run_full_health_monitor.sh" >/dev/null 2>&1 || true

if find "$workdir/tmp" -maxdepth 1 -type d -name 'linux_maint_run.*' | grep -q .; then
  echo "expected run tmp dir cleanup under $workdir/tmp" >&2
  find "$workdir/tmp" -maxdepth 1 -type d -name 'linux_maint_run.*' >&2 || true
  exit 1
fi

echo "wrapper tmpdir cleanup ok"
