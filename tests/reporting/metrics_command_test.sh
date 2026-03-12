#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d)"
cleanup() {
  rm -rf "$workdir"
}
trap cleanup EXIT

log_dir="$workdir/logs"
cfg_dir="$workdir/cfg"
mkdir -p "$log_dir" "$cfg_dir"
printf '%s\n' localhost > "$cfg_dir/servers.txt"
: > "$cfg_dir/excluded.txt"
: > "$cfg_dir/services.txt"

cat > "$log_dir/full_health_monitor_summary_latest.log" <<'EOF'
monitor=network_monitor host=web-1 status=CRIT reason=http_failed
monitor=service_monitor host=web-2 status=WARN reason=service_inactive
EOF

cat > "$log_dir/last_status_full" <<'EOF'
overall=CRIT
exit_code=2
timestamp=2026-03-11T00:00:00Z
run_id=run-metrics-command-001
EOF

cat > "$log_dir/full_health_monitor_2026-03-11_000000.log" <<'EOF'
RUNTIME monitor=network_monitor ms=2500
RUNTIME monitor=service_monitor ms=1200
EOF
ln -sfn "full_health_monitor_2026-03-11_000000.log" "$log_dir/full_health_monitor_latest.log"

out="$(LOG_DIR="$log_dir" SUMMARY_DIR="$log_dir" LM_CFG_DIR="$cfg_dir" bash "$LM" metrics --json 2>/dev/null || true)"

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
