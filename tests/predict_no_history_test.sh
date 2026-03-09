#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

json_out="$(LM_STATE_DIR="$workdir" LM_RUN_INDEX_FILE="$workdir/run_index.jsonl" bash "$LM" predict --last 5 --json 2>/dev/null)"
JSON_OUT="$json_out" python3 - <<'PY'
import json, os
obj = json.loads(os.environ["JSON_OUT"])
assert obj["predict_contract_version"] == 1
assert obj["runs_considered"] == 0
assert obj["risk_score"] == 0
assert obj["risk_level"] == "low"
assert obj["confidence_level"] == "low"
assert obj["recommended_action"] == "observe"
tot = obj.get("totals") or {}
assert tot == {"crit": 0, "warn": 0, "unknown": 0}
PY

echo "predict no history ok"
