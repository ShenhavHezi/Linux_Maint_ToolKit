#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"
LOG_DIR="$ROOT_DIR/.logs"
mkdir -p "$LOG_DIR"

SUMMARY_FILE="$LOG_DIR/full_health_monitor_summary_latest.log"
STATUS_FILE="$LOG_DIR/last_status_full"
LOG_FILE="$LOG_DIR/full_health_monitor_latest.log"
SUMMARY_JSON="$LOG_DIR/full_health_monitor_summary_latest.json"

bak_summary="$(mktemp "${TMPDIR}"/lm_summary_bak.XXXXXX)"
bak_status="$(mktemp "${TMPDIR}"/lm_status_bak.XXXXXX)"
bak_log="$(mktemp "${TMPDIR}"/lm_log_bak.XXXXXX)"
bak_json="$(mktemp "${TMPDIR}"/lm_json_bak.XXXXXX)"
had_summary=0
had_status=0
had_log=0
had_json=0

if [[ -f "$SUMMARY_FILE" ]]; then
  cp "$SUMMARY_FILE" "$bak_summary"
  had_summary=1
fi
if [[ -f "$STATUS_FILE" ]]; then
  cp "$STATUS_FILE" "$bak_status"
  had_status=1
fi
if [[ -f "$LOG_FILE" ]]; then
  cp "$LOG_FILE" "$bak_log"
  had_log=1
fi
if [[ -f "$SUMMARY_JSON" ]]; then
  cp "$SUMMARY_JSON" "$bak_json"
  had_json=1
fi

cleanup(){
  if [[ "$had_summary" -eq 1 ]]; then
    cp "$bak_summary" "$SUMMARY_FILE"
  else
    rm -f "$SUMMARY_FILE"
  fi
  if [[ "$had_status" -eq 1 ]]; then
    cp "$bak_status" "$STATUS_FILE"
  else
    rm -f "$STATUS_FILE"
  fi
  if [[ "$had_log" -eq 1 ]]; then
    cp "$bak_log" "$LOG_FILE"
  else
    rm -f "$LOG_FILE"
  fi
  if [[ "$had_json" -eq 1 ]]; then
    cp "$bak_json" "$SUMMARY_JSON"
  else
    rm -f "$SUMMARY_JSON"
  fi
  rm -f "$bak_summary" "$bak_status" "$bak_log" "$bak_json"
}
trap cleanup EXIT

cat > "$STATUS_FILE" <<'S'
status=ok
timestamp=2099-01-01T00:00:00+00:00
host=testnode
S

cat > "$SUMMARY_FILE" <<'S'
monitor=health_monitor host=server-a status=OK
monitor=network_monitor host=server-a status=WARN reason=ping_failed
S

cat > "$LOG_FILE" <<'S'
[2099-01-01 00:00:00] SUMMARY_RESULT overall=WARN ok=1 warn=1 crit=0 unknown=0 skipped=0 exit_code=1
[2099-01-01 00:00:00] SUMMARY_HOSTS ok=1 warn=1 crit=0 unknown=0 skipped=0
S

rm -f "$SUMMARY_JSON"

csv_out="$(bash "$LM" export --csv | tr -d '\r')"
printf '%s\n' "$csv_out" | head -n 1 | grep -q '^monitor,host,status,reason$'
printf '%s\n' "$csv_out" | grep -q '^health_monitor,server-a,OK,'
printf '%s\n' "$csv_out" | grep -q '^network_monitor,server-a,WARN,ping_failed$'

echo "export csv ok"
