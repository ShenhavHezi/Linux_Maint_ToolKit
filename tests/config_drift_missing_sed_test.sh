#!/usr/bin/env bash
echo "##active_line2##"
set -euo pipefail
echo "##active_line3##"

echo "##active_line4##"
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
echo "##active_line5##"

echo "##active_line6##"
export LM_MODE=repo
echo "##active_line7##"
export LM_LOG_DIR="$ROOT_DIR/.logs"
echo "##active_line8##"
mkdir -p "$LM_LOG_DIR"
echo "##active_line9##"

echo "##active_line10##"
export LM_FORCE_MISSING_DEPS="sed"
echo "##active_line11##"
set +e
echo "##active_line12##"
out="$("$ROOT_DIR"/monitors/config_drift_monitor.sh 2>/dev/null)"
echo "##active_line13##"
rc=$?
echo "##active_line14##"
set -e
echo "##active_line15##"

echo "##active_line16##"
printf "
" "$out" | grep -q "monitor=config_drift_monitor"
echo "##active_line17##"
printf "
" "$out" | grep -q "status=UNKNOWN"
echo "##active_line18##"
printf "
" "$out" | grep -q "reason=missing_dependency"
echo "##active_line19##"
[ "$rc" -eq 3 ]
echo "##active_line20##"

echo "##active_line21##"
unset LM_FORCE_MISSING_DEPS
echo "##active_line22##"
echo "config drift missing sed ok"
echo "##active_line23##"
