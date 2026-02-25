#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

out="$(bash "$LM" run --only service_monitor,ntp_drift_monitor --skip ntp_drift_monitor --hosts localhost --dry-run --debug 2>&1 || true)"

printf '%s\n' "$out" | grep -q 'LM_MONITORS=service_monitor.sh' || {
  echo "expected LM_MONITORS to include service_monitor.sh" >&2
  echo "$out" >&2
  exit 1
}

if printf '%s\n' "$out" | grep -q 'ntp_drift_monitor.sh'; then
  echo "expected ntp_drift_monitor.sh to be skipped" >&2
  echo "$out" >&2
  exit 1
fi

echo "run --only/--skip ok"
