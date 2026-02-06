#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

sudo -n true >/dev/null 2>&1 || { echo "sudo without password required for this test" >&2; exit 0; }

sudo bash "$ROOT_DIR/run_full_health_monitor.sh" >/dev/null 2>&1 || true
summary="$ROOT_DIR/.logs/full_health_monitor_summary_latest.log"

[ -f "$summary" ] || { echo "Missing summary file: $summary" >&2; exit 1; }

# Fail if any non-OK status line lacks reason=
missing=$(awk '
  /^monitor=/ {
    st=""; has_reason=0;
    for(i=1;i<=NF;i++){
      if($i ~ /^status=/){split($i,a,"="); st=a[2]}
      if($i ~ /^reason=/){has_reason=1}
    }
    if(st!="" && st!="OK" && has_reason==0){print $0}
  }
' "$summary" || true)

if [ -n "$missing" ]; then
  echo "Found non-OK summary lines missing reason=:" >&2
  echo "$missing" >&2
  exit 1
fi

echo "reason lint ok"
