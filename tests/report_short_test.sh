#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

out="$(bash "$LM" report --short --no-color 2>/dev/null || true)"

printf '%s\n' "$out" | grep -q '^=== linux-maint report (short) ===' || {
  echo "report --short header missing" >&2
  echo "$out" >&2
  exit 1
}

printf '%s\n' "$out" | grep -q '^mode=' || {
  echo "report --short mode missing" >&2
  echo "$out" >&2
  exit 1
}

printf '%s\n' "$out" | grep -q '^totals:' || {
  echo "report --short totals missing" >&2
  echo "$out" >&2
  exit 1
}

printf '%s\n' "$out" | grep -q '^next_steps:' || {
  echo "report --short next_steps missing" >&2
  echo "$out" >&2
  exit 1
}

lines=$(printf '%s\n' "$out" | wc -l | awk '{print $1}')
if [[ "$lines" -gt 30 ]]; then
  echo "report --short too long ($lines lines)" >&2
  echo "$out" >&2
  exit 1
fi

echo "report short ok"
