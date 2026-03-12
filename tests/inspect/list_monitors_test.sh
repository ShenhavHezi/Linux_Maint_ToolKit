#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

out="$(bash "$LM" list-monitors)"
if ! grep -q "health_monitor" <<< "$out"; then
  echo "list-monitors missing health_monitor" >&2
  exit 1
fi

out_json="$(bash "$LM" list-monitors --json 2>/dev/null || true)"
if [ -z "$out_json" ]; then
  echo "list-monitors --json empty" >&2
  exit 1
fi
case "$out_json" in
  \{* ) ;;
  * ) echo "list-monitors --json non-JSON" >&2; echo "$out_json" >&2; exit 1 ;;
 esac
if ! grep -q "monitors" <<< "$out_json"; then
  echo "list-monitors --json missing monitors" >&2
  exit 1
fi

echo "list-monitors test ok"
