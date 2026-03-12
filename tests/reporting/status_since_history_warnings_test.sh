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
overall=WARN
exit_code=1
timestamp=2026-03-11T01:02:03Z
run_id=run-status-since-001
EOF

cat > "$log_dir/full_health_monitor_summary_latest.log" <<'EOF'
monitor=service_monitor host=web-1 status=WARN reason=failed_units
EOF

cat > "$log_dir/full_health_monitor_summary_2099-12-31_000000.log" <<'EOF'
monitor=service_monitor host=web-1 status=WARN reason=failed_units
EOF

cat > "$log_dir/full_health_monitor_summary_2099-12-31_000001.log" <<'EOF'
monitor=service_monitor host=web-2 reason=missing_status
EOF

json_out="$(LOG_DIR="$log_dir" LM_CFG_DIR="$cfg_dir" bash "$LM" status --json --since 1d)"
printf '%s' "$json_out" | python3 -c 'import json,sys; o=json.load(sys.stdin); assert o["totals"]["WARN"]==1; assert any(p.get("reason")=="failed_units" for p in o["problems"]); warns=o.get("history_warnings", []); assert len(warns)==1; assert warns[0]["state"]=="malformed"; assert warns[0]["file"].endswith("000001.log")'

human_out="$(NO_COLOR=1 LOG_DIR="$log_dir" LM_CFG_DIR="$cfg_dir" bash "$LM" status --since 1d)"
printf '%s\n' "$human_out" | grep -q '^History warnings:$' || {
  echo "status --since should show history warnings" >&2
  echo "$human_out" >&2
  exit 1
}
printf '%s\n' "$human_out" | grep -q 'skipped malformed history file: .*000001.log' || {
  echo "status --since missing malformed history warning" >&2
  echo "$human_out" >&2
  exit 1
}
printf '%s\n' "$human_out" | grep -q 'WARN service_monitor host=web-1 reason=failed_units' || {
  echo "status --since should keep valid history rows" >&2
  echo "$human_out" >&2
  exit 1
}

echo "status since history warnings ok"
