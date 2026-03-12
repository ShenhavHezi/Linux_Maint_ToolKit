#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
log_dir="$workdir/logs"
cfg_dir="$workdir/etc"
mkdir -p "$log_dir" "$cfg_dir"
trap 'rm -rf "$workdir"' EXIT

printf '%s\n' localhost > "$cfg_dir/servers.txt"
: > "$cfg_dir/excluded.txt"
: > "$cfg_dir/services.txt"

cat > "$log_dir/last_status_full" <<'EOF'
status=warn
timestamp=2026-03-11T01:02:03Z
host=testnode
EOF

cat > "$log_dir/full_health_monitor_summary_latest.log" <<'EOF'
monitor=service_monitor host=web-1 status=WARN reason=failed_units
EOF

json_out="$(LOG_DIR="$log_dir" LM_CFG_DIR="$cfg_dir" bash "$LM" status --json)"
human_out="$(NO_COLOR=1 LOG_DIR="$log_dir" LM_CFG_DIR="$cfg_dir" bash "$LM" status)"

printf '%s' "$json_out" | python3 -c 'import json,sys; obj=json.load(sys.stdin); assert obj["status_json_contract_version"]==1; assert obj["last_status_state"]=="malformed"; assert "missing:overall" in obj["last_status_errors"]; assert "missing:exit_code" in obj["last_status_errors"]; assert "missing:run_id" in obj["last_status_errors"]; assert obj["totals"]["WARN"]==1'

printf '%s\n' "$human_out" | grep -q '^Malformed status file: ' || {
  echo "status should report malformed status file" >&2
  echo "$human_out" >&2
  exit 1
}

echo "status malformed last_status ok"
