#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"
EXPECTED="$ROOT_DIR/tests/fixtures/help_top_level_golden.txt"

out="$(NO_COLOR=1 bash "$LM" help 2>/dev/null || true)"

if ! diff -u "$EXPECTED" <(printf '%s\n' "$out") >/dev/null; then
  echo "top-level help golden mismatch" >&2
  diff -u "$EXPECTED" <(printf '%s\n' "$out") >&2 || true
  exit 1
fi

echo "help top-level golden ok"
