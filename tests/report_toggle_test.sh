#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

out="$(bash "$LM" report --no-trend --no-slow 2>&1 || true)"
printf '%s\n' "$out" | grep -q '^trend ' && {
  echo "report --no-trend should suppress trend section" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q '^slow monitors' && {
  echo "report --no-slow should suppress slow monitors section" >&2
  echo "$out" >&2
  exit 1
}

echo "report toggle ok"
