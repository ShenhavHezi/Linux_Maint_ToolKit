#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

set +e
out="$(bash "$LM" metrics 2>&1)"
rc=$?
set -e

if [[ "$rc" -ne 2 ]]; then
  echo "expected metrics rc=2 without output format, got $rc" >&2
  echo "$out" >&2
  exit 1
fi

printf '%s\n' "$out" | grep -q '^ERROR: metrics output is JSON-only (use --json) or --prom$' || {
  echo "metrics missing usage error" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q '^Hint: use linux-maint report or linux-maint status for human-readable output$' || {
  echo "metrics missing human-output hint" >&2
  echo "$out" >&2
  exit 1
}

echo "metrics usage hint ok"
