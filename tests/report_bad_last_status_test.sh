#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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

set +e
out="$(LOG_DIR="$log_dir" LM_CFG_DIR="$cfg_dir" bash "$LM" report --json 2>&1)"
rc=$?
set -e

if [[ "$rc" -ne 2 ]]; then
  echo "expected report bad last_status rc=2, got rc=$rc" >&2
  echo "$out" >&2
  exit 1
fi

printf '%s\n' "$out" | grep -q '^ERROR: report requires readable last_status_full metadata from status --json$' || {
  echo "unexpected report bad last_status output" >&2
  echo "$out" >&2
  exit 1
}

echo "report bad last_status ok"
