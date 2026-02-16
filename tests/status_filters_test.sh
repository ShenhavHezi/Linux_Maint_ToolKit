#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"
LOG_DIR="$ROOT_DIR/.logs"
mkdir -p "$LOG_DIR"

SUMMARY_FILE="$LOG_DIR/full_health_monitor_summary_latest.log"
STATUS_FILE="$LOG_DIR/last_status_full"

bak_summary="$(mktemp /tmp/lm_summary_bak.XXXXXX)"
bak_status="$(mktemp /tmp/lm_status_bak.XXXXXX)"
had_summary=0
had_status=0

if [[ -f "$SUMMARY_FILE" ]]; then
  cp "$SUMMARY_FILE" "$bak_summary"
  had_summary=1
fi
if [[ -f "$STATUS_FILE" ]]; then
  cp "$STATUS_FILE" "$bak_status"
  had_status=1
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
  rm -f "$bak_summary" "$bak_status"
}
trap cleanup EXIT

cat > "$STATUS_FILE" <<'S'
status=warn
timestamp=2026-02-15T00:00:00+00:00
S

cat > "$SUMMARY_FILE" <<'S'
monitor=service_monitor host=web-1 status=WARN reason=failed_units
monitor=service_monitor host=db-1 status=OK
monitor=network_monitor host=web-1 status=CRIT reason=http_down
monitor=backup_check host=backup-1 status=SKIP reason=missing_targets_file
S

out="$(bash "$LM" status --quiet --host web --monitor service --only WARN)"
echo "$out" | grep -q 'totals: CRIT=0 WARN=1 UNKNOWN=0 SKIP=0 OK=0'
echo "$out" | grep -q 'WARN service_monitor host=web-1 reason=failed_units'

# exact mode should match only full values
exact_out="$(bash "$LM" status --quiet --host web-1 --monitor service_monitor --match-mode exact --only WARN)"
echo "$exact_out" | grep -q 'totals: CRIT=0 WARN=1 UNKNOWN=0 SKIP=0 OK=0'
echo "$exact_out" | grep -q 'WARN service_monitor host=web-1 reason=failed_units'

# regex mode should work across compact and json paths
regex_out="$(bash "$LM" status --quiet --host '^web-[0-9]+$' --monitor '^service_.*' --match-mode regex --only WARN)"
echo "$regex_out" | grep -q 'totals: CRIT=0 WARN=1 UNKNOWN=0 SKIP=0 OK=0'

json_out="$(bash "$LM" status --json --host web --monitor service --only WARN)"
printf '%s' "$json_out" | python3 -c 'import json,sys; o=json.load(sys.stdin); assert o["totals"]["WARN"]==1; assert o["totals"]["CRIT"]==0; assert len(o["problems"])==1; p=o["problems"][0]; assert p["monitor"]=="service_monitor"; assert p["host"]=="web-1"'

json_exact="$(bash "$LM" status --json --host web-1 --monitor service_monitor --match-mode exact --only WARN)"
printf '%s' "$json_exact" | python3 -c 'import json,sys; o=json.load(sys.stdin); assert len(o["problems"])==1; assert o["problems"][0]["host"]=="web-1"'

set +e
bad_regex_out="$(bash "$LM" status --json --host '[' --match-mode regex 2>&1)"
bad_regex_rc=$?
set -e
if [[ "$bad_regex_rc" -ne 2 ]]; then
  echo "expected rc=2 for invalid regex, got rc=$bad_regex_rc" >&2
  echo "$bad_regex_out" >&2
  exit 1
fi
echo "$bad_regex_out" | grep -q 'ERROR: invalid regex for --match-mode regex'

echo "status filters ok"
