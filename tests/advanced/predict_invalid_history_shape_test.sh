#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

run_index="$workdir/run_index.jsonl"
cat > "$run_index" <<'JSON'
{"timestamp":"2026-03-10T00:00:00Z","overall":"WARN","exit_code":1,"hosts":[]}
JSON

set +e
out="$(LM_RUN_INDEX_FILE="$run_index" bash "$LM" predict --last 5 --json 2>&1)"
rc=$?
set -e

if [[ "$rc" -ne 2 ]]; then
  echo "expected predict invalid history shape failure rc=2, got rc=$rc" >&2
  echo "$out" >&2
  exit 1
fi

printf '%s\n' "$out" | grep -q 'predict requires hosts objects from history --json' || {
  echo "unexpected predict invalid history shape output" >&2
  echo "$out" >&2
  exit 1
}

echo "predict invalid history shape ok"
