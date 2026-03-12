#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"
EXPECTED="$ROOT_DIR/tests/fixtures/help_menu_golden.txt"

out="$(NO_COLOR=1 bash "$LM" help menu 2>/dev/null || true)"

if ! diff -u "$EXPECTED" <(printf '%s\n' "$out") >/dev/null; then
  echo "help menu golden mismatch" >&2
  diff -u "$EXPECTED" <(printf '%s\n' "$out") >&2 || true
  exit 1
fi

echo "help menu golden ok"
