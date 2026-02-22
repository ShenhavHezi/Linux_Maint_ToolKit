#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

# Force color without TTY should emit ANSI
color_out="$(NO_COLOR='' LM_FORCE_COLOR=1 bash "$LM" report --table 2>/dev/null || true)"
printf '%s\n' "$color_out" | grep -q $'\033' || {
  echo "expected ANSI with LM_FORCE_COLOR=1" >&2
  echo "$color_out" >&2
  exit 1
}

# NO_COLOR must override LM_FORCE_COLOR
no_color_out="$(NO_COLOR=1 LM_FORCE_COLOR=1 bash "$LM" report --table 2>/dev/null || true)"
printf '%s\n' "$no_color_out" | grep -q $'\033' && {
  echo "NO_COLOR should override LM_FORCE_COLOR" >&2
  echo "$no_color_out" >&2
  exit 1
}

echo "color precedence ok"
