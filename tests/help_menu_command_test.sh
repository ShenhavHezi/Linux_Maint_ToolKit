#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

out="$(bash "$LM" help menu 2>&1 || true)"
printf '%s\n' "$out" | grep -q '^Usage: linux-maint menu' || {
  echo "help menu missing usage" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q 'LM_TUI_DEFAULT_PROBLEMS' || {
  echo "help menu missing menu env docs" >&2
  echo "$out" >&2
  exit 1
}

echo "help menu command ok"
