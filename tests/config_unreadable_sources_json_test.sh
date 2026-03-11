#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

cfg="$(mktemp -d)"
trap 'chmod 600 "$cfg/linux-maint.conf" 2>/dev/null || true; rm -rf "$cfg"' EXIT

printf 'LM_NOTIFY=1\n' > "$cfg/linux-maint.conf"
chmod 000 "$cfg/linux-maint.conf"

set +e
out="$(LM_CFG_DIR="$cfg" bash "$LM" config --json 2>&1)"
rc=$?
set -e

if [[ "$rc" -ne 1 ]]; then
  echo "expected config unreadable source rc=1, got rc=$rc" >&2
  echo "$out" >&2
  exit 1
fi

printf '%s' "$out" | python3 "$ROOT_DIR/tools/json_schema_validate.py" "$ROOT_DIR/docs/schemas/config.json"
CONFIG_JSON="$out" python3 - <<'PY'
import json, os
o = json.loads(os.environ["CONFIG_JSON"])
assert o["schema_version"] == 1
assert o["config_json_contract_version"] == 1
assert o["error"] == "unreadable_sources"
assert len(o["unreadable_sources"]) == 1
assert o["unreadable_sources"][0].endswith("/linux-maint.conf")
print("config unreadable sources json ok")
PY

echo "config unreadable sources json ok"
