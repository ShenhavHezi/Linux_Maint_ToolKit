#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

out="$(bash "$LM" metrics --json 2>/dev/null || true)"

METRICS_JSON="$out" python3 - <<'PY'
import json
import os

obj = json.loads(os.environ["METRICS_JSON"])
for key in (
    "metrics_json_contract_version",
    "status",
    "severity_totals",
    "host_counts",
    "monitor_durations_ms",
):
    assert key in obj, f"metrics --json missing {key}"
PY

printf '%s' "$out" | python3 "$ROOT_DIR/tools/json_schema_validate.py" "$ROOT_DIR/docs/schemas/metrics.json"

echo "metrics command ok"
