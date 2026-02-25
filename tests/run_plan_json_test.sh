#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

plan_json="$(NO_COLOR=1 bash "$LM" run --plan --json --local-only)"
python3 - "$plan_json" <<'PY'
import json
import sys

plan = json.loads(sys.argv[1])
if "hosts" not in plan or not isinstance(plan["hosts"], list) or not plan["hosts"]:
    raise SystemExit("plan JSON missing hosts")
if "monitors" not in plan or not isinstance(plan["monitors"], list) or not plan["monitors"]:
    raise SystemExit("plan JSON missing monitors")
print("run plan json ok")
PY
