#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

out="$(bash "$LM" doctor --fix --dry-run --yes --json)"

python3 - <<'PY' "$out"
import json
import sys

obj = json.loads(sys.argv[1])
assert obj.get("doctor_json_contract_version") == 1
fix_actions = obj.get("fix_actions")
assert isinstance(fix_actions, list)
assert fix_actions, "expected at least one doctor fix action in dry-run output"
assert any(entry.get("status") == "dry_run" for entry in fix_actions)
PY

echo "doctor --fix repo-mode non-root ok"
