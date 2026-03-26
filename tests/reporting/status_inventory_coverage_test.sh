#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

log_dir="$workdir/logs"
cfg_dir="$workdir/cfg"
mkdir -p "$log_dir" "$cfg_dir/hosts.d"
printf '%s\n' web-1 web-2 > "$cfg_dir/servers.txt"
: > "$cfg_dir/excluded.txt"
: > "$cfg_dir/services.txt"
cat > "$cfg_dir/inventory_meta.csv" <<'EOF'
host,tags,role,env
web-1,ops;web,web,prod
EOF

cat > "$log_dir/full_health_monitor_summary_latest.log" <<'EOF'
monitor=service_monitor host=web-1 status=WARN reason=service_inactive
monitor=network_monitor host=web-2 status=OK
EOF

cat > "$log_dir/last_status_full" <<'EOF'
overall=WARN
exit_code=1
timestamp=2026-03-26T10:00:00Z
run_id=run-status-inventory-001
EOF

json_out="$(LOG_DIR="$log_dir" SUMMARY_DIR="$log_dir" LM_CFG_DIR="$cfg_dir" NO_COLOR=1 bash "$LM" status --json 2>&1)"
printf '%s' "$json_out" | python3 -c 'import json,sys; o=json.load(sys.stdin); inv=o["inventory"]; assert inv["result"]=="WARN"; assert inv["summary"]["inventory_hosts"]==2; assert inv["summary"]["metadata_hosts"]==1; assert inv["summary"]["missing_metadata_hosts"]==1; assert inv["summary"]["coverage_percent"]==50; assert inv["coverage"]["roles"]==["web"]; assert inv["coverage"]["envs"]==["prod"]; assert "ops" in inv["coverage"]["tags"]; assert inv["warnings"]'

human_out="$(LOG_DIR="$log_dir" SUMMARY_DIR="$log_dir" LM_CFG_DIR="$cfg_dir" NO_COLOR=1 bash "$LM" status --table 2>&1 || true)"
for required in \
  '^=== Inventory metadata ===$' \
  '^result=WARN$' \
  '^inventory_hosts=2 metadata_hosts=1 coverage=50%$' \
  '^missing_metadata_hosts=1 extra_metadata_hosts=0 invalid_rows=0$' \
  '^next_step: linux-maint inventory lint$' \
  '^inventory_result=WARN$' \
  '^inventory_warnings=1$' \
  '^inventory_coverage=1/2$'
do
  printf '%s\n' "$human_out" | grep -q "$required" || {
    echo "status inventory output missing pattern: $required" >&2
    echo "$human_out" >&2
    exit 1
  }
done

echo "status inventory coverage ok"
