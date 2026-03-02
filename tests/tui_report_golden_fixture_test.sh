#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

repo_logs="$ROOT_DIR/.logs"
workdir="$(mktemp -d)"
backup="$workdir/logs_backup"

cleanup() {
  rm -rf "$repo_logs" 2>/dev/null || true
  if [[ -d "$backup" ]]; then
    mv "$backup" "$repo_logs"
  fi
  rm -rf "$workdir"
}
trap cleanup EXIT

if [[ -d "$repo_logs" ]]; then
  mv "$repo_logs" "$backup"
fi
mkdir -p "$repo_logs"

cat > "$repo_logs/full_health_monitor_summary_latest.log" <<'S'
monitor=service_monitor host=web-1 status=WARN reason=service_inactive
monitor=network_monitor host=web-2 status=CRIT reason=http_failed
monitor=backup_check host=backup-1 status=OK
S

cat > "$repo_logs/last_status_full" <<'S'
overall=CRIT
exit_code=2
timestamp=2026-02-24T00:00:00Z
logfile=/var/log/health/full_health_monitor_latest.log
S

out="$(NO_COLOR=1 bash "$LM" report --short --no-trend --no-slow --no-reasons 2>/dev/null || true)"
expected_file="$ROOT_DIR/tests/fixtures/tui_report_golden.txt"

if ! diff -u "$expected_file" <(printf '%s\n' "$out") >/dev/null; then
  echo "tui report golden output mismatch" >&2
  diff -u "$expected_file" <(printf '%s\n' "$out") >&2 || true
  exit 1
fi

echo "tui report golden fixture ok"
