#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

LOG_DIR="$(mktemp -d)"
trap 'rm -rf "$LOG_DIR"' EXIT

f1="$LOG_DIR/full_health_monitor_summary_9999-12-30_235958.log"
f2="$LOG_DIR/full_health_monitor_summary_9999-12-31_235959.log"

cat > "$f1" <<'S'
monitor=service_monitor host=web-1 status=WARN reason=failed_units
monitor=network_monitor host=web-1 status=CRIT reason=http_down
monitor=backup_check host=backup-1 status=OK
S

cat > "$f2" <<'S'
monitor=service_monitor host=web-2 status=WARN reason=failed_units
monitor=nfs_mount_monitor host=db-1 status=UNKNOWN reason=ssh_unreachable
monitor=backup_check host=backup-2 status=SKIP reason=missing_targets_file
S

out="$(NO_COLOR=1 LOG_DIR="$LOG_DIR" bash "$LM" trend --last 2)"
normalized="$(printf '%s
' "$out" | sed -E "s#source_dir=.*#source_dir=<LOG_DIR>#")"

expected_file="$ROOT_DIR/tests/fixtures/trend_golden.txt"
if ! diff -u "$expected_file" <(printf '%s
' "$normalized") >/dev/null; then
  echo "trend golden output mismatch" >&2
  diff -u "$expected_file" <(printf '%s
' "$normalized") >&2 || true
  exit 1
fi

echo "trend golden fixture ok"
