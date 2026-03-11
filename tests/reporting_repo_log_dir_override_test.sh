#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

logdir="$workdir/logs"
summarydir="$workdir/summary"
cfgdir="$workdir/etc_linux_maint"
statedir="$workdir/state"
mkdir -p "$logdir" "$summarydir" "$cfgdir" "$statedir"

cat > "$logdir/last_status_full" <<'EOF'
overall=WARN
exit_code=1
timestamp=2099-01-01T00:00:00+00:00
run_id=test-run
EOF

cat > "$summarydir/full_health_monitor_summary_latest.log" <<'EOF'
monitor=service_monitor host=web-1 status=WARN reason=failed_units
EOF

cat > "$summarydir/full_health_monitor_summary_latest.json" <<'EOF'
{
  "rows": [
    {"monitor": "service_monitor", "host": "web-1", "status": "WARN", "reason": "failed_units"}
  ]
}
EOF

cat > "$summarydir/full_health_monitor_summary_2099-01-01_000000.log" <<'EOF'
monitor=service_monitor host=web-1 status=WARN reason=failed_units
EOF

cat > "$logdir/full_health_monitor_latest.log" <<'EOF'
[2099-01-01 00:00:00] SUMMARY_RESULT overall=WARN ok=0 warn=1 crit=0 unknown=0 skipped=0 exit_code=1
[2099-01-01 00:00:00] SUMMARY_HOSTS ok=0 warn=1 crit=0 unknown=0 skipped=0
EOF

status_out="$(LOG_DIR="$logdir" SUMMARY_DIR="$summarydir" LM_CFG_DIR="$cfgdir" LM_STATE_DIR="$statedir" bash "$LM" status --json)"
printf '%s' "$status_out" | python3 -c 'import json,sys; o=json.load(sys.stdin); assert o["summary_file"].startswith(sys.argv[1]); assert o["totals"]["WARN"] == 1' "$summarydir"

report_out="$(LOG_DIR="$logdir" SUMMARY_DIR="$summarydir" LM_CFG_DIR="$cfgdir" LM_STATE_DIR="$statedir" bash "$LM" report --json)"
printf '%s' "$report_out" | python3 -c 'import json,sys; o=json.load(sys.stdin); assert o["status"]["summary_file"].startswith(sys.argv[1]); assert o["status"]["totals"]["WARN"] == 1' "$summarydir"

export_out="$(LOG_DIR="$logdir" SUMMARY_DIR="$summarydir" LM_CFG_DIR="$cfgdir" LM_STATE_DIR="$statedir" bash "$LM" export --json)"
printf '%s' "$export_out" | python3 -c 'import json,sys; o=json.load(sys.stdin); assert o["summary_file"].startswith(sys.argv[1]); assert o["summary_json"].startswith(sys.argv[1]); assert o["summary_result"]["overall"] == "WARN"; assert len(o["rows"]) == 1' "$summarydir"

trend_out="$(LOG_DIR="$logdir" SUMMARY_DIR="$summarydir" LM_CFG_DIR="$cfgdir" LM_STATE_DIR="$statedir" bash "$LM" trend --last 1 --json)"
printf '%s' "$trend_out" | python3 -c 'import json,sys; o=json.load(sys.stdin); assert len(o["runs"]) == 1; assert o["runs"][0]["totals"]["WARN"] == 1'

echo "reporting repo summary dir override ok"
