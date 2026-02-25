#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

index="$workdir/run_index.jsonl"
cat > "$index" <<'JSONL'
{"timestamp":"2026-02-24T00:00:00Z","overall":"OK","exit_code":0}
{"timestamp":"2026-02-24T01:00:00Z","overall":"WARN","exit_code":1}
{"timestamp":"2026-02-24T02:00:00Z","overall":"CRIT","exit_code":2}
{"timestamp":"2026-02-24T03:00:00Z","overall":"OK","exit_code":0}
JSONL

out="$(LM_STATE_DIR="$workdir" LM_RUN_INDEX_FILE="$index" bash "$LM" run-index --prune --keep 2)"

lines=$(wc -l < "$index" | tr -d ' ')
if [[ "$lines" -ne 2 ]]; then
  echo "expected 2 lines after prune, got $lines" >&2
  cat "$index" >&2
  exit 1
fi

echo "$out" | grep -q 'run_index_pruned'

echo "run index prune ok"
