#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

set +e
out="$(bash "$LM" agent --interval 0 --max-runs 1 --dry-run 2>&1)"
rc=$?
set -e

if [[ "$rc" -ne 2 ]]; then
  echo "expected agent --interval 0 failure rc=2, got rc=$rc" >&2
  echo "$out" >&2
  exit 1
fi

printf '%s\n' "$out" | grep -q '^ERROR: --interval must be a positive integer$' || {
  echo "unexpected agent interval validation output" >&2
  echo "$out" >&2
  exit 1
}

echo "agent interval validation ok"
