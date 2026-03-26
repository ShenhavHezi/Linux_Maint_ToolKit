#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

cfg_dir="$workdir/etc_linux_maint"
mkdir -p "$cfg_dir/hosts.d"
printf '%s\n' web-01 db-01 cache-01 > "$cfg_dir/servers.txt"
printf '%s\n' web-02 > "$cfg_dir/hosts.d/prod.txt"
: > "$cfg_dir/excluded.txt"
cat > "$cfg_dir/inventory_meta.csv" <<'EOF'
host,tags,role,env,owner
web-01,web;;frontend,web,prod,ops
web-01,web|frontend,web,prod,ops
web-02,web;frontend,,prod,ops
db-01,db;stateful,db,,ops
orphan-01,orphan,ops,dev,ops
EOF

set +e
json_out="$("$LM" inventory lint --cfg-dir "$cfg_dir" --json 2>&1)"
rc=$?
set -e
[[ "$rc" -eq 1 ]] || {
  echo "expected inventory lint findings rc=1, got $rc" >&2
  echo "$json_out" >&2
  exit 1
}

printf '%s' "$json_out" | python3 "$ROOT_DIR/tools/json_schema_validate.py" "$ROOT_DIR/docs/schemas/inventory_lint.json"

python3 - <<'PY' "$json_out"
import json
import sys

payload = json.loads(sys.argv[1])
assert payload["result"] == "WARN", payload
assert payload["header_ok"] is False, payload
assert "owner" in payload["unknown_columns"], payload
assert payload["summary"]["duplicate_hosts"] == 1, payload
assert payload["summary"]["missing_metadata_hosts"] == 1, payload
assert payload["summary"]["extra_metadata_hosts"] == 1, payload
assert payload["summary"]["invalid_rows"] >= 3, payload
assert "web-01" in payload["duplicate_hosts"], payload
assert "cache-01" in payload["missing_metadata_hosts"], payload
assert "orphan-01" in payload["extra_metadata_hosts"], payload
assert payload["warnings"], payload
assert payload["next_steps"], payload
PY

set +e
human_out="$("$LM" inventory lint --cfg-dir "$cfg_dir" 2>&1)"
rc=$?
set -e
[[ "$rc" -eq 1 ]] || {
  echo "expected inventory lint human findings rc=1, got $rc" >&2
  echo "$human_out" >&2
  exit 1
}

for required in \
  '^Duplicate hosts:$' \
  '^Missing metadata hosts:$' \
  '^Extra metadata hosts:$' \
  '^Row issues:$' \
  '^== Guidance ==$' \
  '^== Summary ==$' \
  '^inventory lint warn$'
do
  printf '%s\n' "$human_out" | grep -q "$required" || {
    echo "inventory lint findings output missing pattern: $required" >&2
    echo "$human_out" >&2
    exit 1
  }
done

echo "inventory lint findings ok"
