#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"
LOG_DIR="$ROOT_DIR/.logs"
mkdir -p "$LOG_DIR"

SUMMARY_FILE="$LOG_DIR/full_health_monitor_summary_latest.log"
STATUS_FILE="$LOG_DIR/last_status_full"
SUMMARY_JSON="$LOG_DIR/full_health_monitor_summary_latest.json"

bak_dir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$bak_dir"' EXIT

backup_file() {
  local f="$1"
  if [[ -e "$f" ]]; then
    cp -p "$f" "$bak_dir/$(basename "$f")"
  fi
}

restore_file() {
  local f="$1"
  local b="$bak_dir/$(basename "$f")"
  if [[ -e "$b" ]]; then
    cp -p "$b" "$f"
  else
    rm -f "$f"
  fi
}

backup_file "$SUMMARY_FILE"
backup_file "$STATUS_FILE"
backup_file "$SUMMARY_JSON"

# Clean any existing trend/runtime fixtures created by this test.
rm -f "$LOG_DIR"/full_health_monitor_summary_2099-01-01_000000.log \
      "$LOG_DIR"/full_health_monitor_2099-01-01_000000.log

cleanup() {
  restore_file "$SUMMARY_FILE"
  restore_file "$STATUS_FILE"
  restore_file "$SUMMARY_JSON"
  rm -f "$LOG_DIR"/full_health_monitor_summary_2099-01-01_000000.log \
        "$LOG_DIR"/full_health_monitor_2099-01-01_000000.log
}
trap cleanup EXIT

cat > "$STATUS_FILE" <<'S'
status=warn
timestamp=2099-01-01T00:00:00+00:00
host=testnode
overall=WARN
exit_code=1
logfile=/tmp/test.log
S

cat > "$SUMMARY_FILE" <<'S'
monitor=service_monitor host=web-1 status=WARN reason=failed_units
monitor=network_monitor host=web-1 status=CRIT reason=http_down
monitor=backup_check host=backup-1 status=SKIP reason=missing_targets_file
monitor=service_monitor host=db-1 status=OK
S

cat > "$SUMMARY_JSON" <<'S'
{
  "meta": {
    "timestamp": "2099-01-01T00:00:00+00:00",
    "host": "testnode",
    "overall": "WARN",
    "exit_code": "1",
    "logfile": "/tmp/test.log"
  },
  "rows": [
    {"monitor": "service_monitor", "host": "web-1", "status": "WARN", "reason": "failed_units"}
  ]
}
S

cat > "$LOG_DIR/full_health_monitor_summary_2099-01-01_000000.log" <<'S'
monitor=service_monitor host=web-1 status=WARN reason=failed_units
monitor=network_monitor host=web-1 status=CRIT reason=http_down
S

cat > "$LOG_DIR/full_health_monitor_2099-01-01_000000.log" <<'S'
RUNTIME monitor=health_monitor ms=123
S

assert_clean() {
  local label="$1"
  python3 - "$label" <<'PY'
import sys
label = sys.argv[1]
data = sys.stdin.read()
for ch in data:
    o = ord(ch)
    if o < 32 and ch not in ("\n", "\r", "\t"):
        print(f"FAIL: {label} contains control char 0x{o:02x}", file=sys.stderr)
        sys.exit(1)
print("ok")
PY
}

run_and_check() {
  local label="$1"; shift
  local out
  out="$(LM_FORCE_COLOR=1 NO_COLOR='' bash "$LM" "$@" 2>/dev/null || true)"
  printf '%s' "$out" | assert_clean "$label" >/dev/null
}

run_and_check "status_json" status --json
run_and_check "report_json" report --json
run_and_check "trend_json" trend --json --last 1
run_and_check "runtimes_json" runtimes --json --last 1
run_and_check "metrics_json" metrics --json
run_and_check "export_json" export --json

echo "json output clean ok"
