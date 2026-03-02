#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

json_out="$(bash "$LM" predict --last 5 --json 2>/dev/null || true)"
JSON_OUT="$json_out" python3 - <<'PY'
import json, os
obj = json.loads(os.environ["JSON_OUT"])
assert obj["predict_contract_version"] == 1
assert "runs_considered" in obj
assert "risk_score" in obj
assert obj.get("risk_level") in ("low", "medium", "high")
assert obj.get("confidence_level") in ("low", "medium", "high")
assert obj.get("recommended_action") in ("observe", "schedule_investigation", "open_incident")
tot = obj.get("totals") or {}
assert "crit" in tot and "warn" in tot and "unknown" in tot
PY

echo "predict command ok"
