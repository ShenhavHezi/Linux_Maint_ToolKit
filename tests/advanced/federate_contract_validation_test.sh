#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

bad_json="$workdir/bad-status.json"
cat > "$bad_json" <<'JSON'
{
  "totals": {
    "CRIT": 0,
    "WARN": 1,
    "UNKNOWN": 0,
    "SKIP": 0,
    "OK": 0
  },
  "last_status": {
    "overall": "WARN"
  }
}
JSON

set +e
out="$(bash "$LM" federate --input "$bad_json" --json 2>&1)"
rc=$?
set -e

if [[ "$rc" -ne 2 ]]; then
  echo "expected federate contract validation failure rc=2, got rc=$rc" >&2
  echo "$out" >&2
  exit 1
fi

printf '%s\n' "$out" | grep -q 'missing status contract version' || {
  echo "unexpected federate contract validation output" >&2
  echo "$out" >&2
  exit 1
}

echo "federate contract validation ok"
