#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

out="$(bash "$LM" summary 2>&1 || true)"
printf '%s\n' "$out" | grep -q 'overall=' || {
  echo "summary missing overall" >&2
  echo "$out" >&2
  exit 1
}

no_color_out="$(NO_COLOR=1 bash "$LM" summary 2>/dev/null || true)"
printf '%s\n' "$no_color_out" | grep -q $'\033' && {
  echo "summary should not contain ANSI when NO_COLOR=1" >&2
  echo "$no_color_out" >&2
  exit 1
}

echo "summary command ok"
