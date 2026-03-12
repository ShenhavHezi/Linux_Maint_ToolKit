#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

cfg="$(mktemp -d)"
trap 'rm -rf "$cfg"' EXIT

cat > "$cfg/linux-maint.conf" <<'EOF'
LM_FOO=bar
exit 7
EOF

set +e
out="$(LM_CFG_DIR="$cfg" bash "$LM" config --json 2>&1)"
rc=$?
set -e

if [[ "$rc" -ne 1 ]]; then
  echo "expected config source failure rc=1, got rc=$rc" >&2
  echo "$out" >&2
  exit 1
fi

printf '%s' "$out" | python3 "$ROOT_DIR/tools/json_schema_validate.py" "$ROOT_DIR/docs/schemas/config.json"
CONFIG_JSON="$out" python3 - <<'PY'
import json, os
o = json.loads(os.environ["CONFIG_JSON"])
assert o["schema_version"] == 1
assert o["config_json_contract_version"] == 1
assert o["error"] == "source_failed"
assert "message" in o and o["message"]
assert len(o["sources"]) == 1
print("config source failure ok")
PY
