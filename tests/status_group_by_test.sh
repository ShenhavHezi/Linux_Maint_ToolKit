#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT_DIR/.logs"
SUMMARY_FILE="$LOG_DIR/full_health_monitor_summary_latest.log"

mkdir -p "$LOG_DIR"

backup=""
if [[ -f "$SUMMARY_FILE" ]]; then
  backup="$SUMMARY_FILE.bak.$$"
  cp -f "$SUMMARY_FILE" "$backup"
fi

cleanup() {
  if [[ -n "$backup" && -f "$backup" ]]; then
    mv -f "$backup" "$SUMMARY_FILE"
  else
    rm -f "$SUMMARY_FILE"
  fi
}
trap cleanup EXIT

cat > "$SUMMARY_FILE" <<'SUM'
monitor=service_monitor host=host-a status=CRIT reason=service_failed
monitor=service_monitor host=host-b status=WARN reason=service_failed
monitor=disk_trend_monitor host=host-b status=OK
monitor=timer_monitor host=host-c status=SKIP reason=timer_missing
monitor=health_monitor host=host-a status=OK
monitor=network_monitor host=host-c status=UNKNOWN reason=ssh_unreachable
SUM

out_host="$("$ROOT_DIR"/bin/linux-maint status --compact --group-by host --no-color)"
python3 - <<'PY' "$out_host"
import sys
out = sys.argv[1].splitlines()
assert any(line.strip() == "group_by=host" for line in out), "missing group_by=host"
rows = [line for line in out if line.startswith("host-")]
order = [line.split()[0] for line in rows]
expected = ["host-a", "host-b", "host-c"]
assert order == expected, f"unexpected host order: {order}"
print("status group-by host ok")
PY

out_reason="$("$ROOT_DIR"/bin/linux-maint status --compact --group-by reason --no-color)"
python3 - <<'PY' "$out_reason"
import sys
out = sys.argv[1].splitlines()
assert any(line.strip() == "group_by=reason" for line in out), "missing group_by=reason"
rows = [line for line in out if line.startswith("service_failed") or line.startswith("ssh_unreachable") or line.startswith("timer_missing")]
order = [line.split()[0] for line in rows]
expected = ["service_failed", "ssh_unreachable", "timer_missing"]
assert order == expected, f"unexpected reason order: {order}"
print("status group-by reason ok")
PY
