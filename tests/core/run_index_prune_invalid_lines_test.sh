#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

index_file="$workdir/run_index.jsonl"
cat > "$index_file" <<'JSON'
{"timestamp":"2026-02-24T10:00:00+0000","overall":"OK","exit_code":0,"hosts":{"ok":10,"warn":0,"crit":0,"unknown":0,"skipped":0}}
not-json
JSON

set +e
out="$(LM_RUN_INDEX_FILE="$index_file" bash "$LM" run-index --prune --keep 1 --json 2>&1)"
rc=$?
set -e

if [[ "$rc" -ne 2 ]]; then
  echo "expected run-index prune invalid lines rc=2, got rc=$rc" >&2
  echo "$out" >&2
  exit 1
fi

printf '%s' "$out" | python3 -c 'import json,sys; o=json.load(sys.stdin); assert o["schema_version"]==1; assert o["run_index_command_json_contract_version"]==1; assert o["action"]=="prune"; assert o["exists"] is True; assert o["invalid_lines"]==1; assert o["error"]=="invalid_lines"; assert "message" in o'
printf '%s' "$out" | python3 "$ROOT_DIR/tools/json_schema_validate.py" "$ROOT_DIR/docs/schemas/run_index_command.json"

lines=$(wc -l < "$index_file" | tr -d ' ')
if [[ "$lines" -ne 2 ]]; then
  echo "expected prune invalid-lines failure to leave index unchanged, got $lines lines" >&2
  cat "$index_file" >&2
  exit 1
fi

echo "run-index prune invalid lines ok"
