#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
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
run_id=run-status-001
EOF

cat > "$log_dir/full_health_monitor_summary_latest.log" <<'EOF'
monitor=service_monitor host=web-1 status=WARN reason=failed_units
EOF

cat > "$log_dir/full_health_monitor_latest.log" <<'EOF'
[2026-03-11 01:02:03] SUMMARY_RESULT overall=WARN exit_code=1
[2026-03-11 01:02:03] SUMMARY_HOSTS ok=0 warn=1 crit=0 unknown=0 skipped=0
EOF

run_status_json() {
  LOG_DIR="$log_dir" LM_CFG_DIR="$cfg_dir" bash "$LM" status --json
}

run_status_human() {
  NO_COLOR=1 LOG_DIR="$log_dir" LM_CFG_DIR="$cfg_dir" bash "$LM" status
}

if [[ "$(id -u)" -eq 0 ]]; then
  if command -v su >/dev/null 2>&1 && id nobody >/dev/null 2>&1; then
    chmod 0755 "$workdir" "$log_dir" "$cfg_dir"
    chmod 0644 "$log_dir/last_status_full" "$log_dir/full_health_monitor_latest.log"
    chmod 0644 "$cfg_dir/servers.txt" "$cfg_dir/excluded.txt" "$cfg_dir/services.txt"
    chmod 000 "$log_dir/full_health_monitor_summary_latest.log"
    json_out="$(su -s /bin/bash nobody -c "LOG_DIR='$log_dir' LM_CFG_DIR='$cfg_dir' bash '$LM' status --json" 2>&1)"
    human_out="$(su -s /bin/bash nobody -c "NO_COLOR=1 LOG_DIR='$log_dir' LM_CFG_DIR='$cfg_dir' bash '$LM' status" 2>&1)"
  else
    echo "status unreadable summary skipped under root: no su/nobody"
    exit 0
  fi
else
  chmod 000 "$log_dir/full_health_monitor_summary_latest.log"
  json_out="$(run_status_json 2>&1)"
  human_out="$(run_status_human 2>&1)"
fi

printf '%s' "$json_out" | python3 -c 'import json,sys; obj=json.load(sys.stdin); assert obj["status_json_contract_version"]==1; assert obj["last_status"]["run_id"]=="run-status-001"; assert obj["totals"]["WARN"]==0; assert obj["problems"]==[]'

printf '%s\n' "$human_out" | grep -q '^Unreadable summary file: ' || {
  echo "status should report unreadable summary file" >&2
  echo "$human_out" >&2
  exit 1
}
printf '%s\n' "$human_out" | grep -q '^Falling back to grepping latest wrapper log$' || {
  echo "status should fall back to latest wrapper log" >&2
  echo "$human_out" >&2
  exit 1
}
if printf '%s\n' "$human_out" | grep -Eq 'Traceback|Permission denied'; then
  echo "status leaked raw permission error output" >&2
  echo "$human_out" >&2
  exit 1
fi

echo "status unreadable summary ok"
