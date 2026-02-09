#!/usr/bin/env bash
set -euo pipefail

# Lint: summary lines should stay reasonably small.
# This is a guardrail for P3.2 (reduce summary noise).

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

max_len="${LM_SUMMARY_MAX_LEN:-220}"

# Generate a summary log in repo-local mode (best-effort)
"$ROOT_DIR/run_full_health_monitor.sh" >/dev/null 2>&1 || true

summary="$ROOT_DIR/.logs/full_health_monitor_summary_latest.log"
[ -f "$summary" ] || { echo "missing summary log: $summary" >&2; exit 0; }

fail=0
while IFS= read -r line || [ -n "$line" ]; do
  [[ -z "$line" ]] && continue
  len=${#line}
  if [ "$len" -gt "$max_len" ]; then
    echo "FAIL: summary line too long ($len > $max_len): $line" >&2
    fail=1
  fi

done < "$summary"

[ "$fail" -eq 0 ]

echo "summary noise lint ok (max_len=$max_len)"
