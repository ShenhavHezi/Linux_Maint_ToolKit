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
EOF

cat > "$log_dir/last_status_full" <<'EOF'
overall=CRIT
exit_code=2
timestamp=2026-03-11T00:00:00Z
run_id=run-color-001
EOF

# Force color without TTY should emit ANSI
color_out="$(NO_COLOR='' LM_FORCE_COLOR=1 LOG_DIR="$log_dir" SUMMARY_DIR="$log_dir" LM_CFG_DIR="$cfg_dir" bash "$LM" report --table 2>/dev/null || true)"
printf '%s\n' "$color_out" | grep -q $'\033' || {
  echo "expected ANSI with LM_FORCE_COLOR=1" >&2
  echo "$color_out" >&2
  exit 1
}

# NO_COLOR must override LM_FORCE_COLOR
no_color_out="$(NO_COLOR=1 LM_FORCE_COLOR=1 LOG_DIR="$log_dir" SUMMARY_DIR="$log_dir" LM_CFG_DIR="$cfg_dir" bash "$LM" report --table 2>/dev/null || true)"
printf '%s\n' "$no_color_out" | grep -q $'\033' && {
  echo "NO_COLOR should override LM_FORCE_COLOR" >&2
  echo "$no_color_out" >&2
  exit 1
}

echo "color precedence ok"
