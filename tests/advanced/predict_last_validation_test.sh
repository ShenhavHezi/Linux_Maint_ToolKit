#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

set +e
out="$(bash "$LM" predict --last 0 --json 2>&1)"
rc=$?
set -e

if [[ "$rc" -ne 2 ]]; then
  echo "expected predict --last 0 failure rc=2, got rc=$rc" >&2
  echo "$out" >&2
  exit 1
fi

printf '%s\n' "$out" | grep -q '^ERROR: --last must be a positive integer$' || {
  echo "unexpected predict validation output" >&2
  echo "$out" >&2
  exit 1
}

echo "predict last validation ok"
