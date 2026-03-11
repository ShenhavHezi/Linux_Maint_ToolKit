#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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
monitor=backup_check host=backup-1 status=OK
EOF

cat > "$log_dir/last_status_full" <<'EOF'
overall=CRIT
exit_code=2
timestamp=2026-03-11T00:00:00Z
run_id=run-report-command-001
EOF

cat > "$log_dir/full_health_monitor_2026-03-11_000000.log" <<'EOF'
RUNTIME monitor=network_monitor ms=2500
RUNTIME monitor=service_monitor ms=1200
EOF
ln -sfn "full_health_monitor_2026-03-11_000000.log" "$log_dir/full_health_monitor_latest.log"

common_env=(
  "LOG_DIR=$log_dir"
  "SUMMARY_DIR=$log_dir"
  "LM_CFG_DIR=$cfg_dir"
)

out="$(env "${common_env[@]}" NO_COLOR=1 bash "$LM" report 2>&1 || true)"
printf '%s\n' "$out" | grep -q '^=== linux-maint report ===' || {
  echo "report header missing" >&2
  echo "$out" >&2
  exit 1
}

printf '%s\n' "$out" | grep -q '^mode=' || {
  echo "report mode missing" >&2
  echo "$out" >&2
  exit 1
}

json_out="$(env "${common_env[@]}" bash "$LM" report --json 2>/dev/null || true)"
printf '%s\n' "$json_out" | grep -q '"status"' || {
  echo "report --json missing status key" >&2
  echo "$json_out" >&2
  exit 1
}
printf '%s' "$json_out" | python3 "$ROOT_DIR/tools/json_schema_validate.py" "$ROOT_DIR/docs/schemas/report.json"

compact_out="$(env "${common_env[@]}" bash "$LM" report --compact --no-color 2>/dev/null || true)"
printf '%s\n' "$compact_out" | grep -q '^totals:' || {
  echo "report --compact missing totals line" >&2
  echo "$compact_out" >&2
  exit 1
}

table_out="$(env "${common_env[@]}" NO_COLOR=1 bash "$LM" report --table 2>/dev/null || true)"
printf '%s\n' "$table_out" | grep -Eq '^STATUS[[:space:]]+MONITOR' || {
  echo "report --table missing header" >&2
  echo "$table_out" >&2
  exit 1
}
printf '%s\n' "$table_out" | grep -q '^totals:' || {
  echo "report --table missing totals table" >&2
  echo "$table_out" >&2
  exit 1
}

no_color_out="$(env "${common_env[@]}" NO_COLOR=1 bash "$LM" report 2>/dev/null || true)"
printf '%s\n' "$no_color_out" | grep -q $'\033' && {
  echo "report should not contain ANSI when NO_COLOR=1" >&2
  echo "$no_color_out" >&2
  exit 1
}

color_out="$(env "${common_env[@]}" NO_COLOR='' LM_FORCE_COLOR=1 bash "$LM" report --table 2>/dev/null || true)"
printf '%s\n' "$color_out" | grep -q $'\033' || {
  echo "report --table should contain ANSI when color enabled" >&2
  echo "$color_out" >&2
  exit 1
}

echo "report command ok"
