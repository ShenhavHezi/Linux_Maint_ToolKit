#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
alt_root="/tmp/linux_maint"
alt_file="$alt_root/run_index.jsonl"
backup=""
trap '
  rm -rf "$workdir"
  rm -f "$alt_file"
  if [[ -n "$backup" && -f "$backup" ]]; then
    mkdir -p "$alt_root"
    mv -f "$backup" "$alt_file"
  fi
' EXIT

if [[ -f "$alt_file" ]]; then
  backup="$workdir/original-run-index.jsonl"
  mv -f "$alt_file" "$backup"
fi

mkdir -p "$alt_root"
printf '%s\n' '{"timestamp":"2026-01-01T00:00:00+0000","overall":"OK","exit_code":0,"hosts":{"ok":1,"warn":0,"crit":0,"unknown":0,"skipped":0}}' > "$alt_file"

missing_state="$workdir/state"
set +e
out="$(LM_STATE_DIR="$missing_state" bash "$LM" run-index --stats --json 2>&1)"
rc=$?
set -e

if [[ "$rc" -ne 1 ]]; then
  echo "expected explicit LM_STATE_DIR to prevent fallback, got rc=$rc" >&2
  echo "$out" >&2
  exit 1
fi

OUT_JSON="$out" python3 - "$missing_state/run_index.jsonl" <<'PY'
import json, os, sys
obj = json.loads(os.environ["OUT_JSON"])
expected = sys.argv[1]
assert obj["schema_version"] == 1
assert obj["run_index_command_json_contract_version"] == 1
assert obj["exists"] is False
assert obj["path"] == expected, obj["path"]
assert obj["error"] == "not_found"
PY

echo "run-index explicit state no fallback ok"
