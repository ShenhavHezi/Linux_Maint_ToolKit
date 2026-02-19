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

echo "report command ok"
