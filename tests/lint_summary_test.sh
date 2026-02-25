#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"
fixture="$ROOT_DIR/tests/fixtures/summary_ok.log"

bash "$LM" lint-summary "$fixture" >/dev/null

out="$(bash "$LM" lint-summary "$fixture" --json 2>/dev/null || true)"
if [ -z "$out" ]; then
  echo "lint-summary --json produced empty output" >&2
  exit 1
fi
case "$out" in
  \{* ) ;;
  * ) echo "lint-summary --json produced non-JSON output" >&2; echo "$out" >&2; exit 1 ;;
 esac

echo "lint-summary test ok"
