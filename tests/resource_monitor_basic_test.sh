#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

out="$({
  LINUX_MAINT_LIB="$ROOT_DIR/lib/linux_maint.sh" \
  LM_LOCKDIR="${TMPDIR}" \
  LM_LOGFILE=${TMPDIR}/linux_maint_resource_test.log \
  bash "$ROOT_DIR/monitors/resource_monitor.sh"
} 2>/dev/null || true)"

# Must emit a summary line
if ! echo "$out" | grep -q '^monitor=resource_monitor '; then
  echo "Expected resource_monitor to emit a monitor= summary line" >&2
  echo "$out" >&2
  exit 1
fi

# Status must be one of allowed values
status="$(echo "$out" | awk '{for(i=1;i<=NF;i++){split($i,a,"="); if(a[1]=="status"){print a[2]; exit}}}')"
case "$status" in
  OK|WARN|CRIT|UNKNOWN|SKIP) ;;
  *)
    echo "Unexpected status: $status" >&2
    echo "$out" >&2
    exit 1
    ;;
esac

echo "resource_monitor basic ok"
