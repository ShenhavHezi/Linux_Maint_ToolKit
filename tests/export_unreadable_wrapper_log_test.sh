#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
log_dir="$workdir/logs"
cfg_dir="$workdir/etc"
mkdir -p "$log_dir" "$cfg_dir"
trap 'chmod 0644 "$log_dir/full_health_monitor_latest.log" 2>/dev/null || true; rm -rf "$workdir"' EXIT

printf '%s\n' localhost > "$cfg_dir/servers.txt"
: > "$cfg_dir/excluded.txt"
: > "$cfg_dir/services.txt"

cat > "$log_dir/last_status_full" <<'EOF'
overall=CRIT
exit_code=2
timestamp=2026-03-11T01:02:03Z
run_id=run-export-002
EOF

cat > "$log_dir/full_health_monitor_summary_latest.log" <<'EOF'
monitor=network_monitor host=web-1 status=CRIT reason=http_failed
EOF

cat > "$log_dir/full_health_monitor_summary_latest.json" <<'EOF'
{
  "meta": {
    "generated_at": "2026-03-11T01:02:03Z"
  },
  "rows": [
    {"monitor": "network_monitor", "host": "web-1", "status": "CRIT", "reason": "http_failed"}
  ]
}
EOF

cat > "$log_dir/full_health_monitor_latest.log" <<'EOF'
[2026-03-11 01:02:03] SUMMARY_RESULT overall=CRIT exit_code=2
[2026-03-11 01:02:03] SUMMARY_HOSTS ok=0 warn=0 crit=1 unknown=0 skipped=0
EOF

run_export() {
  LOG_DIR="$log_dir" LM_CFG_DIR="$cfg_dir" bash "$LM" export --json
}

if [[ "$(id -u)" -eq 0 ]]; then
  if command -v su >/dev/null 2>&1 && id nobody >/dev/null 2>&1; then
    chmod 0755 "$workdir" "$log_dir" "$cfg_dir"
    chmod 0644 "$log_dir/last_status_full" "$log_dir/full_health_monitor_summary_latest.log" "$log_dir/full_health_monitor_summary_latest.json"
    chmod 0644 "$cfg_dir/servers.txt" "$cfg_dir/excluded.txt" "$cfg_dir/services.txt"
    chmod 000 "$log_dir/full_health_monitor_latest.log"
    out="$(su -s /bin/bash nobody -c "LOG_DIR='$log_dir' LM_CFG_DIR='$cfg_dir' bash '$LM' export --json" 2>&1)"
  else
    echo "export unreadable wrapper log skipped under root: no su/nobody"
    exit 0
  fi
else
  chmod 000 "$log_dir/full_health_monitor_latest.log"
  out="$(run_export 2>&1)"
fi

printf '%s' "$out" | python3 -c 'import json,sys; obj=json.load(sys.stdin); assert obj["export_json_contract_version"]==1; assert obj["last_status"]["run_id"]=="run-export-002"; assert obj["summary_result"]["overall"]=="CRIT"; assert obj["summary_result_source"]=="derived"; assert obj["summary_hosts"]["crit"]==1; assert obj["summary_hosts_source"]=="derived"; assert len(obj["rows"])==1'

if printf '%s\n' "$out" | grep -Eq 'Traceback|Permission denied'; then
  echo "export leaked raw permission error output" >&2
  echo "$out" >&2
  exit 1
fi

echo "export unreadable wrapper log ok"
