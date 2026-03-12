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
overall=CRIT
exit_code=2
timestamp=2026-03-11T01:02:03Z
run_id=run-export-001
EOF

cat > "$log_dir/full_health_monitor_summary_latest.log" <<'EOF'
monitor=network_monitor host=web-1 status=CRIT reason=http_failed
EOF

rm -f "$log_dir/full_health_monitor_summary_latest.json"

run_export() {
  LOG_DIR="$log_dir" LM_CFG_DIR="$cfg_dir" bash "$LM" export --json
}

if [[ "$(id -u)" -eq 0 ]]; then
  if command -v su >/dev/null 2>&1 && id nobody >/dev/null 2>&1; then
    chmod 0755 "$workdir" "$log_dir" "$cfg_dir"
    chmod 0644 "$log_dir/last_status_full"
    chmod 0644 "$cfg_dir/servers.txt" "$cfg_dir/excluded.txt" "$cfg_dir/services.txt"
    chmod 000 "$log_dir/full_health_monitor_summary_latest.log"
    set +e
    out="$(su -s /bin/bash nobody -c "LOG_DIR='$log_dir' LM_CFG_DIR='$cfg_dir' bash '$LM' export --json" 2>&1)"
    rc=$?
    set -e
  else
    echo "export unreadable summary log skipped under root: no su/nobody"
    exit 0
  fi
else
  chmod 000 "$log_dir/full_health_monitor_summary_latest.log"
  set +e
  out="$(run_export 2>&1)"
  rc=$?
  set -e
fi

if [[ "$rc" -ne 2 ]]; then
  echo "expected export unreadable summary log rc=2, got rc=$rc" >&2
  echo "$out" >&2
  exit 1
fi

printf '%s\n' "$out" | grep -q '^ERROR: export requires readable summary log at ' || {
  echo "unexpected export unreadable summary log output" >&2
  echo "$out" >&2
  exit 1
}

echo "export unreadable summary log ok"
