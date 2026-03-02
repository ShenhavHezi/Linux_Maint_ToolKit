#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

json_out="$(bash "$LM" ai-assist --json 2>/dev/null || true)"
JSON_OUT="$json_out" python3 - <<'PY'
import json, os
obj = json.loads(os.environ["JSON_OUT"])
assert obj["ai_assist_contract_version"] == 1
assert isinstance(obj.get("hints"), list)
assert len(obj["hints"]) >= 1
assert "overall" in obj
PY

echo "ai-assist command ok"
