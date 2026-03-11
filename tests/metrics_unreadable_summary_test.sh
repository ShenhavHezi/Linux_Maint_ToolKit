#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
log_dir="$workdir/logs"
cfg_dir="$workdir/etc"
mkdir -p "$log_dir" "$cfg_dir"
trap 'chmod 0644 "$log_dir/full_health_monitor_summary_latest.log" 2>/dev/null || true; rm -rf "$workdir"' EXIT

printf '%s\n' localhost > "$cfg_dir/servers.txt"
: > "$cfg_dir/excluded.txt"
: > "$cfg_dir/services.txt"

cat > "$log_dir/last_status_full" <<'EOF'
overall=WARN
exit_code=1
timestamp=2026-03-11T01:02:03Z
run_id=run-metrics-001
EOF

cat > "$log_dir/full_health_monitor_summary_latest.log" <<'EOF'
monitor=service_monitor host=web-1 status=WARN reason=failed_units
EOF

cat > "$log_dir/full_health_monitor_latest.log" <<'EOF'
[2026-03-11 01:02:03] RUNTIME monitor=service_monitor ms=1200
[2026-03-11 01:02:03] SUMMARY_RESULT overall=WARN exit_code=1
[2026-03-11 01:02:03] SUMMARY_HOSTS ok=0 warn=1 crit=0 unknown=0 skipped=0
EOF

run_metrics() {
  LOG_DIR="$log_dir" SUMMARY_DIR="$log_dir" LM_CFG_DIR="$cfg_dir" bash "$LM" metrics --json
}

if [[ "$(id -u)" -eq 0 ]]; then
  if command -v su >/dev/null 2>&1 && id nobody >/dev/null 2>&1; then
    chmod 0755 "$workdir" "$log_dir" "$cfg_dir"
    chmod 0644 "$log_dir/last_status_full" "$log_dir/full_health_monitor_latest.log"
    chmod 0644 "$cfg_dir/servers.txt" "$cfg_dir/excluded.txt" "$cfg_dir/services.txt"
    chmod 000 "$log_dir/full_health_monitor_summary_latest.log"
    set +e
    out="$(su -s /bin/bash nobody -c "HOME='$workdir' LOG_DIR='$log_dir' SUMMARY_DIR='$log_dir' LM_CFG_DIR='$cfg_dir' bash '$LM' metrics --json" 2>&1)"
    rc=$?
    set -e
    if [[ "$rc" -ne 0 ]]; then
      echo "metrics unreadable summary root-path failure rc=$rc" >&2
      echo "$out" >&2
      exit 1
    fi
  else
    echo "metrics unreadable summary skipped under root: no su/nobody"
    exit 0
  fi
else
  chmod 000 "$log_dir/full_health_monitor_summary_latest.log"
  out="$(run_metrics 2>&1)"
fi

printf '%s' "$out" | python3 -c 'import json,sys; obj=json.load(sys.stdin); assert obj["metrics_json_contract_version"]==1; assert obj["status"]["last_status"]["run_id"]=="run-metrics-001"; assert obj["severity_totals"]["WARN"]==0; assert obj["host_counts"]["WARN"]==0; assert isinstance(obj["slow_monitors_top"], list)'

if printf '%s\n' "$out" | grep -Eq 'Traceback|Permission denied'; then
  echo "metrics leaked raw permission error output" >&2
  echo "$out" >&2
  exit 1
fi

echo "metrics unreadable summary ok"
