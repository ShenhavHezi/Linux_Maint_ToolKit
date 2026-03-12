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

cat > "$log_dir/full_health_monitor_summary_2099-12-31_000000.log" <<'EOF'
monitor=service_monitor host=web-1 status=WARN reason=failed_units
EOF

cat > "$log_dir/full_health_monitor_summary_2099-12-31_000001.log" <<'EOF'
monitor=service_monitor host=web-2 reason=missing_status
EOF

touch -d '2099-12-31 00:00:00' "$log_dir/full_health_monitor_summary_2099-12-31_000000.log" 2>/dev/null || true
touch -d '2099-12-31 00:00:01' "$log_dir/full_health_monitor_summary_2099-12-31_000001.log" 2>/dev/null || true

out="$(NO_COLOR=1 LOG_DIR="$log_dir" LM_CFG_DIR="$cfg_dir" bash "$LM" status --last 1)"

printf '%s\n' "$out" | grep -q 'full_health_monitor_summary_2099-12-31_000000.log CRIT=0 WARN=1' || {
  echo "status --last should show the older valid run counts when newest is malformed" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q '^History warnings:$' || {
  echo "status --last should show history warnings" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q 'skipped malformed history file: .*000001.log' || {
  echo "status --last missing malformed history warning" >&2
  echo "$out" >&2
  exit 1
}

echo "status last history warnings ok"
