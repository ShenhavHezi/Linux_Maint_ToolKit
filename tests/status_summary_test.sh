#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

out="$(bash "$LM" status --summary 2>&1 || true)"
printf '%s\n' "$out" | grep -q 'overall=' || {
  echo "status --summary missing overall" >&2
  echo "$out" >&2
  exit 1
}

out_table="$(bash "$LM" status --summary --table 2>&1 || true)"
printf '%s\n' "$out_table" | grep -q 'overall=' || {
  echo "status --summary --table missing summary" >&2
  echo "$out_table" >&2
  exit 1
}
printf '%s\n' "$out_table" | grep -q '^STATUS[[:space:]]+MONITOR' || {
  echo "status --summary --table missing table header" >&2
  echo "$out_table" >&2
  exit 1
}

color_out="$(bash "$LM" status --summary --table 2>/dev/null || true)"
printf '%s\n' "$color_out" | grep -q $'\033' || {
  echo "status --table should contain ANSI when color enabled" >&2
  echo "$color_out" >&2
  exit 1
}

echo "status summary ok"

compact_out="$(bash "$LM" status --compact 2>/dev/null || true)"
printf '%s\n' "$compact_out" | grep -q '=== Mode ===' && {
  echo "status --compact should hide mode header" >&2
  echo "$compact_out" >&2
  exit 1
}

echo "status compact ok"
