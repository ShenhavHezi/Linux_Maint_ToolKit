#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

log_dir="$ROOT_DIR/.logs"
mkdir -p "$log_dir"
summary_file="$log_dir/full_health_monitor_summary_latest.log"
status_file="$log_dir/last_status_full"

if ! touch "$status_file" 2>/dev/null; then
  echo "status prom unreadable summary skipped: cannot write $status_file"
  exit 0
fi

cleanup() {
  chmod 0644 "$summary_file" 2>/dev/null || true
}
trap cleanup EXIT

cat > "$status_file" <<'EOF'
timestamp=2026-03-02T10:00:00Z
exit_code=0
overall=OK
EOF
cat > "$summary_file" <<'EOF'
monitor=health_monitor host=runner status=OK reason=ok node=runner
EOF
chmod 000 "$summary_file"

out="$(bash "$LM" status --prom 2>/dev/null || true)"
printf '%s\n' "$out" | grep -q '^linux_maint_status_count{status="ok"} ' || {
  echo "status --prom did not emit counters when summary unreadable" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q '^linux_maint_last_run_exit_code ' || {
  echo "status --prom missing last_run_exit_code" >&2
  echo "$out" >&2
  exit 1
}

echo "status prom unreadable summary ok"
