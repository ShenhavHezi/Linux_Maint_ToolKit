#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

out="$(bash "$LM" doctor --fix --dry-run 2>&1 || true)"
printf '%s\n' "$out" | grep -qi 'requires root' || {
  echo "doctor --fix should require root" >&2
  echo "$out" >&2
  exit 1
}

echo "doctor --fix root check ok"
