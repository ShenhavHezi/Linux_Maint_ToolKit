#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}" )/.." && pwd)"
TEST_TMP="${LM_TEST_TMPDIR:-$ROOT_DIR/.tmp_test}"
mkdir -p "$TEST_TMP"
export TMPDIR="${TMPDIR:-$TEST_TMP}"

export LINUX_MAINT_LIB="$ROOT_DIR/lib/linux_maint.sh"
export LM_LOCKDIR="$TMPDIR"
export LM_LOGFILE="${TMPDIR}/linux_maint_contract_test.log"
export LM_EMAIL_ENABLED="false"
export LM_STATE_DIR="$TMPDIR"
export LM_SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=3"
export LM_SERVERLIST="/dev/null"
export LM_EXCLUDED="/dev/null"
export LM_LOCAL_ONLY="true"
export LM_INVENTORY_OUTPUT_DIR="${TMPDIR}/linux_maint_inventory"
mkdir -p "$LM_INVENTORY_OUTPUT_DIR" >/dev/null 2>&1 || true

monitors=(
  preflight_check.sh
  config_validate.sh
  health_monitor.sh
  inode_monitor.sh
  disk_trend_monitor.sh
  network_monitor.sh
  service_monitor.sh
  ntp_drift_monitor.sh
  patch_monitor.sh
  storage_health_monitor.sh
  kernel_events_monitor.sh
  cert_monitor.sh
  nfs_mount_monitor.sh
  ports_baseline_monitor.sh
  config_drift_monitor.sh
  user_monitor.sh
  backup_check.sh
  inventory_export.sh
)

summary_tmp="$(mktemp)"
trap 'rm -f "$summary_tmp"' EXIT

for m in "${monitors[@]}"; do
  path="$ROOT_DIR/monitors/$m"
  out="$(mktemp)"
  # best-effort: ignore rc
  set +e
  LM_LOGFILE="${TMPDIR}/${m%.sh}.log" bash -lc "bash \"$path\"" >"$out" 2>&1
  set -e
  grep '^monitor=' "$out" >>"$summary_tmp" || true
  rm -f "$out"
done

python3 "$ROOT_DIR/tests/summary_parse_safety_lint.py" "$summary_tmp"
