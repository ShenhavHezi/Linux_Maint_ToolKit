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
run_id=run-metrics-top-slow-001
EOF

cat > "$log_dir/full_health_monitor_2026-03-11_000000.log" <<'EOF'
RUNTIME monitor=network_monitor ms=2500
RUNTIME monitor=service_monitor ms=1200
RUNTIME monitor=backup_check ms=100
EOF
ln -sfn "full_health_monitor_2026-03-11_000000.log" "$log_dir/full_health_monitor_latest.log"

out="$(LM_METRICS_TOP_SLOW=3 LOG_DIR="$log_dir" SUMMARY_DIR="$log_dir" LM_CFG_DIR="$cfg_dir" bash "$LM" metrics --json 2>/dev/null || true)"

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
