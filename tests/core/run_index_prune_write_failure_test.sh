#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d)"
trap 'chmod 700 "$workdir" 2>/dev/null || true; rm -rf "$workdir"' EXIT

index_file="$workdir/run_index.jsonl"
cat > "$index_file" <<'JSON'
{"timestamp":"2026-02-24T10:00:00+0000","overall":"OK","exit_code":0,"hosts":{"ok":10,"warn":0,"crit":0,"unknown":0,"skipped":0}}
{"timestamp":"2026-02-24T11:00:00+0000","overall":"WARN","exit_code":1,"hosts":{"ok":9,"warn":1,"crit":0,"unknown":0,"skipped":0}}
{"timestamp":"2026-02-24T12:00:00+0000","overall":"CRIT","exit_code":2,"hosts":{"ok":8,"warn":1,"crit":1,"unknown":0,"skipped":0}}
JSON

chmod 500 "$workdir"

set +e
out="$(LM_RUN_INDEX_FILE="$index_file" bash "$LM" run-index --prune --keep 2 --json 2>&1)"
rc=$?
set -e

chmod 700 "$workdir"

if [[ "$rc" -ne 2 ]]; then
  echo "expected run-index prune write failure rc=2, got rc=$rc" >&2
  echo "$out" >&2
  exit 1
fi

printf '%s' "$out" | python3 -c 'import json,sys; o=json.load(sys.stdin); assert o["schema_version"]==1; assert o["run_index_command_json_contract_version"]==1; assert o["action"]=="prune"; assert o["exists"] is True; assert o["error"]=="write_failed"; assert "message" in o'
printf '%s' "$out" | python3 "$ROOT_DIR/tools/json_schema_validate.py" "$ROOT_DIR/docs/schemas/run_index_command.json"

lines=$(wc -l < "$index_file" | tr -d ' ')
if [[ "$lines" -ne 3 ]]; then
  echo "expected prune failure to leave index unchanged, got $lines lines" >&2
  cat "$index_file" >&2
  exit 1
fi

echo "run-index prune write failure ok"
