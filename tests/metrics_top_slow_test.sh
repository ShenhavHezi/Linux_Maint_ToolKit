#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

out="$(LM_METRICS_TOP_SLOW=3 bash "$LM" metrics --json 2>/dev/null || true)"

METRICS_JSON="$out" python3 - <<'PY'
import json, sys
import os
obj = json.loads(os.environ.get("METRICS_JSON","{}"))
assert "monitor_durations_seconds" in obj, "missing monitor_durations_seconds"
assert isinstance(obj["monitor_durations_seconds"], dict), "monitor_durations_seconds should be object"
assert "slow_monitors_top" in obj, "missing slow_monitors_top"
arr = obj["slow_monitors_top"]
assert isinstance(arr, list), "slow_monitors_top should be array"
assert len(arr) <= 3, "LM_METRICS_TOP_SLOW cap not applied"
prev = None
for row in arr:
    assert isinstance(row, dict), "slow monitor row must be object"
    assert "monitor" in row and "ms" in row, "slow monitor row missing monitor/ms"
    ms = int(row["ms"])
    if prev is not None:
        assert ms <= prev, "slow_monitors_top should be sorted desc by ms"
    prev = ms
print("metrics top slow ok")
PY
