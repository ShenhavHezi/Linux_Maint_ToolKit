#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

out="$(bash "$LM" help status 2>&1 || true)"
printf '%s\n' "$out" | grep -q '^Usage: linux-maint status' || {
  echo "help status missing usage" >&2
  echo "$out" >&2
  exit 1
}

echo "help command ok"
