#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

out="$(bash "$LM" report 2>&1 || true)"
printf '%s\n' "$out" | grep -q '^=== linux-maint report ===' || {
  echo "report header missing" >&2
  echo "$out" >&2
  exit 1
}

printf '%s\n' "$out" | grep -q '^mode=' || {
  echo "report mode missing" >&2
  echo "$out" >&2
  exit 1
}

json_out="$(bash "$LM" report --json 2>/dev/null || true)"
printf '%s\n' "$json_out" | grep -q '"status"' || {
  echo "report --json missing status key" >&2
  echo "$json_out" >&2
  exit 1
}
printf '%s' "$json_out" | python3 "$ROOT_DIR/tools/json_schema_validate.py" "$ROOT_DIR/docs/schemas/report.json"

compact_out="$(bash "$LM" report --compact --no-color 2>/dev/null || true)"
printf '%s\n' "$compact_out" | grep -q '^totals:' || {
  echo "report --compact missing totals line" >&2
  echo "$compact_out" >&2
  exit 1
}

table_out="$(bash "$LM" report --table 2>/dev/null || true)"
printf '%s\n' "$table_out" | grep -Eq '^STATUS[[:space:]]+MONITOR' || {
  echo "report --table missing header" >&2
  echo "$table_out" >&2
  exit 1
}
printf '%s\n' "$table_out" | grep -q '^totals:' || {
  echo "report --table missing totals table" >&2
  echo "$table_out" >&2
  exit 1
}

no_color_out="$(NO_COLOR=1 bash "$LM" report 2>/dev/null || true)"
printf '%s\n' "$no_color_out" | grep -q $'\033' && {
  echo "report should not contain ANSI when NO_COLOR=1" >&2
  echo "$no_color_out" >&2
  exit 1
}

color_out="$(NO_COLOR='' LM_FORCE_COLOR=1 bash "$LM" report --table 2>/dev/null || true)"
printf '%s\n' "$color_out" | grep -q $'\033' || {
  echo "report --table should contain ANSI when color enabled" >&2
  echo "$color_out" >&2
  exit 1
}

echo "report command ok"
