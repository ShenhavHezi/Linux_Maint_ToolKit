#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

cfg_dir="$workdir/etc_linux_maint"
mkdir -p "$cfg_dir/hosts.d"
printf '%s\n' web-01 db-01 > "$cfg_dir/servers.txt"
printf '%s\n' web-02 > "$cfg_dir/hosts.d/prod.txt"
: > "$cfg_dir/excluded.txt"
cat > "$cfg_dir/inventory_meta.csv" <<'EOF'
host,tags,role,env
web-01,web;frontend,web,prod
web-02,web;frontend,web,prod
db-01,db;stateful,db,prod
EOF

json_out="$("$LM" inventory lint --cfg-dir "$cfg_dir" --json)"
printf '%s' "$json_out" | python3 "$ROOT_DIR/tools/json_schema_validate.py" "$ROOT_DIR/docs/schemas/inventory_lint.json"

CFG_DIR="$cfg_dir" python3 - <<'PY' "$json_out"
import json
import os
import sys

payload = json.loads(sys.argv[1])
assert payload["inventory_lint_json_contract_version"] == 1, payload
assert payload["cfg_dir"] == os.environ["CFG_DIR"], payload
assert payload["header_ok"] is True, payload
assert payload["summary"]["inventory_hosts"] == 3, payload
assert payload["summary"]["metadata_hosts"] == 3, payload
assert payload["summary"]["missing_metadata_hosts"] == 0, payload
assert payload["summary"]["duplicate_hosts"] == 0, payload
assert payload["summary"]["invalid_rows"] == 0, payload
assert payload["summary"]["groups"] == 1, payload
assert sorted(payload["coverage"]["roles"]) == ["db", "web"], payload
assert payload["coverage"]["envs"] == ["prod"], payload
assert "frontend" in payload["coverage"]["tags"], payload
assert payload["warnings"] == [], payload
assert payload["result"] == "OK", payload
PY

human_out="$("$LM" inventory lint --cfg-dir "$cfg_dir")"
printf '%s\n' "$human_out" | grep -q '^Coverage:$' || {
  echo "inventory lint coverage block missing" >&2
  echo "$human_out" >&2
  exit 1
}
printf '%s\n' "$human_out" | grep -q '^== Summary ==$' || {
  echo "inventory lint summary block missing" >&2
  echo "$human_out" >&2
  exit 1
}
printf '%s\n' "$human_out" | grep -q '^inventory lint ok$' || {
  echo "inventory lint final ok label missing" >&2
  echo "$human_out" >&2
  exit 1
}

echo "inventory lint command ok"
