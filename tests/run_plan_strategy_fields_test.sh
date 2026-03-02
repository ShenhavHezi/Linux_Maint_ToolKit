#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

out="$(bash "$LM" run --plan --json --retry 2 --host-timeout 9 --strategy quorum --quorum-percent 75 2>/dev/null || true)"
STATUS_JSON="$out" python3 - <<'PY'
import json, os
obj = json.loads(os.environ.get("STATUS_JSON", "{}"))
assert obj.get("retry") == 2
assert obj.get("host_timeout") == 9
assert obj.get("strategy") == "quorum"
assert obj.get("quorum_percent") == 75
PY

echo "run plan strategy fields ok"
