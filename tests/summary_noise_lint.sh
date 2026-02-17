#!/usr/bin/env bash
set -euo pipefail

# Lint: summary lines should stay reasonably small.
# Guardrails:
# - global max line length (LM_SUMMARY_MAX_LEN; default 220)
# - optional per-monitor overrides via LM_SUMMARY_MONITOR_MAX_LEN_MAP="monitor_a=180,monitor_b=260"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

max_len="${LM_SUMMARY_MAX_LEN:-220}"
map_raw="${LM_SUMMARY_MONITOR_MAX_LEN_MAP:-inventory_export=260}"

summary="${1:-}"
if [[ -z "$summary" ]]; then
  # Generate a summary log in repo-local mode (best-effort)
  "$ROOT_DIR/run_full_health_monitor.sh" >/dev/null 2>&1 || true
  summary="$ROOT_DIR/.logs/full_health_monitor_summary_latest.log"
fi

[ -f "$summary" ] || { echo "missing summary log: $summary" >&2; exit 0; }

monitor_limit() {
  local monitor="$1" part k v
  IFS=',' read -r -a parts <<< "$map_raw"
  for part in "${parts[@]}"; do
    part="${part//[[:space:]]/}"
    [[ -z "$part" ]] && continue
    [[ "$part" == *=* ]] || continue
    k="${part%%=*}"
    v="${part#*=}"
    if [[ "$k" == "$monitor" && "$v" =~ ^[0-9]+$ ]]; then
      echo "$v"
      return 0
    fi
  done
  echo "$max_len"
}

fail=0
while IFS= read -r line || [ -n "$line" ]; do
  [[ -z "$line" ]] && continue
  mon=""
  if [[ "$line" =~ (^|[[:space:]])monitor=([^[:space:]]+) ]]; then
    mon="${BASH_REMATCH[2]}"
  fi
  limit="$max_len"
  [[ -n "$mon" ]] && limit="$(monitor_limit "$mon")"

  len=${#line}
  if [ "$len" -gt "$limit" ]; then
    echo "FAIL: summary line too long for monitor=${mon:-unknown} ($len > $limit): $line" >&2
    fail=1
  fi

done < "$summary"

[ "$fail" -eq 0 ]

echo "summary noise lint ok (default_max_len=$max_len map=${map_raw:-none})"
