#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

logdir="$workdir/logs"
cfgdir="$workdir/etc_linux_maint"
statedir="$workdir/state"
mkdir -p "$logdir" "$cfgdir" "$statedir"

cat > "$logdir/last_status_full" <<'EOF'
overall=WARN
exit_code=1
timestamp=2099-01-01T00:00:00+00:00
run_id=test-run
EOF

cat > "$logdir/full_health_monitor_summary_latest.log" <<'EOF'
monitor=service_monitor host=web-1 status=WARN reason=failed_units
EOF

cat > "$logdir/full_health_monitor_latest.log" <<'EOF'
[2099-01-01 00:00:00] SUMMARY_RESULT overall=WARN ok=0 warn=1 crit=0 unknown=0 skipped=0 exit_code=1
[2099-01-01 00:00:00] SUMMARY_HOSTS ok=0 warn=1 crit=0 unknown=0 skipped=0
EOF

status_out="$(LOG_DIR="$logdir" LM_CFG_DIR="$cfgdir" LM_STATE_DIR="$statedir" bash "$LM" status --json)"
printf '%s' "$status_out" | python3 -c 'import json,sys; o=json.load(sys.stdin); assert o["summary_file"].startswith(sys.argv[1]); assert o["totals"]["WARN"] == 1' "$logdir"

report_out="$(LOG_DIR="$logdir" LM_CFG_DIR="$cfgdir" LM_STATE_DIR="$statedir" bash "$LM" report --json)"
printf '%s' "$report_out" | python3 -c 'import json,sys; o=json.load(sys.stdin); assert o["status"]["summary_file"].startswith(sys.argv[1]); assert o["status"]["totals"]["WARN"] == 1' "$logdir"

export_out="$(LOG_DIR="$logdir" LM_CFG_DIR="$cfgdir" LM_STATE_DIR="$statedir" bash "$LM" export --json)"
printf '%s' "$export_out" | python3 -c 'import json,sys; o=json.load(sys.stdin); assert o["summary_file"].startswith(sys.argv[1]); assert o["summary_log"].startswith(sys.argv[1]); assert o["summary_result"]["overall"] == "WARN"; assert len(o["rows"]) == 1' "$logdir"

echo "reporting repo log dir override ok"
