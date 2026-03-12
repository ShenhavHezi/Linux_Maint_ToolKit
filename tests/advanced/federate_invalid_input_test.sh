#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

valid="$workdir/status.json"
invalid="$workdir/invalid.json"

cat > "$valid" <<'JSON'
{
  "last_status": { "overall": "OK" },
  "totals": { "CRIT": 0, "WARN": 0, "UNKNOWN": 0, "SKIP": 0, "OK": 1 }
}
JSON

printf '%s\n' '{not-json' > "$invalid"

set +e
json_out="$(bash "$LM" federate --input "$valid,$invalid" --json 2>"$workdir/stderr.txt")"
rc=$?
set -e

if [[ "$rc" -ne 2 ]]; then
  echo "expected federate invalid input rc=2, got rc=$rc" >&2
  echo "$json_out" >&2
  cat "$workdir/stderr.txt" >&2
  exit 1
fi

if [[ -n "$json_out" ]]; then
  echo "expected no JSON output on invalid federate input" >&2
  echo "$json_out" >&2
  exit 1
fi

grep -q 'ERROR: invalid federate input:' "$workdir/stderr.txt" || {
  echo "expected invalid federate input error" >&2
  cat "$workdir/stderr.txt" >&2
  exit 1
}

echo "federate invalid input ok"
