#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

out="$(bash "$LM" metrics --json 2>/dev/null || true)"

printf '%s\n' "$out" | grep -q '"metrics_json_contract_version"' || {
  echo "metrics --json missing contract version" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q '"status"' || {
  echo "metrics --json missing status" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q '"severity_totals"' || {
  echo "metrics --json missing severity_totals" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q '"host_counts"' || {
  echo "metrics --json missing host_counts" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q '"monitor_durations_ms"' || {
  echo "metrics --json missing monitor_durations_ms" >&2
  echo "$out" >&2
  exit 1
}

printf '%s' "$out" | python3 "$ROOT_DIR/tools/json_schema_validate.py" "$ROOT_DIR/docs/schemas/metrics.json"

echo "metrics command ok"
