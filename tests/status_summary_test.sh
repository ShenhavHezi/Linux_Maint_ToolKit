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

echo "status summary ok"
