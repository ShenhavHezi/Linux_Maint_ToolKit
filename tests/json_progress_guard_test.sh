#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

json_out="$(LM_PROGRESS=1 bash "$LM" report --json 2>/dev/null || true)"
JSON_OUT="$json_out" python3 - <<'PY'
import json, os
json.loads(os.environ.get("JSON_OUT", ""))
PY

echo "json progress guard ok"
