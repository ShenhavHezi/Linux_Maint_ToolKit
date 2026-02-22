#!/usr/bin/env bash
set -euo pipefail

# Timer monitor: ensure linux-maint timer is installed/enabled/active (systemd)
. "${LINUX_MAINT_LIB:-/usr/local/lib/linux_maint.sh}" || { echo "Missing ${LINUX_MAINT_LIB:-/usr/local/lib/linux_maint.sh}" >&2; exit 1; }
LM_PREFIX="[timer_monitor] "
LM_LOGFILE="${LM_LOGFILE:-/var/log/timer_monitor.log}"

lm_require_singleton "timer_monitor"

UNIT="${LM_TIMER_UNIT:-linux-maint.timer}"

if ! command -v systemctl >/dev/null 2>&1; then
  lm_summary "timer_monitor" "runner" "SKIP" reason=missing_dependency dep=systemctl
  exit 0
fi

if ! systemctl list-unit-files --no-legend "$UNIT" 2>/dev/null | grep -q "^$UNIT"; then
  lm_summary "timer_monitor" "runner" "SKIP" reason=timer_missing unit="$UNIT"
  exit 0
fi

enabled="disabled"
if systemctl is-enabled "$UNIT" >/dev/null 2>&1; then
  enabled="enabled"
fi

active="inactive"
if systemctl is-active "$UNIT" >/dev/null 2>&1; then
  active="active"
fi

if [[ "$enabled" != "enabled" ]]; then
  lm_summary "timer_monitor" "runner" "WARN" reason=timer_disabled unit="$UNIT"
  exit 0
fi

if [[ "$active" != "active" ]]; then
  lm_summary "timer_monitor" "runner" "WARN" reason=timer_inactive unit="$UNIT"
  exit 0
fi

lm_summary "timer_monitor" "runner" "OK" unit="$UNIT"
exit 0
