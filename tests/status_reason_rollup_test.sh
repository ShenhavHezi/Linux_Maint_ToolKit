#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"
LOG_DIR="$ROOT_DIR/.logs"
mkdir -p "$LOG_DIR"

SUMMARY_FILE="$LOG_DIR/full_health_monitor_summary_latest.log"
STATUS_FILE="$LOG_DIR/last_status_full"

bak_summary="$(mktemp "${TMPDIR}"/lm_summary_bak.XXXXXX)"
bak_status="$(mktemp "${TMPDIR}"/lm_status_bak.XXXXXX)"
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
timestamp=2026-02-17T00:00:00+00:00
S

cat > "$SUMMARY_FILE" <<'S'
monitor=service_monitor host=web-1 status=WARN reason=failed_units
monitor=service_monitor host=web-2 status=WARN reason=failed_units
monitor=network_monitor host=web-1 status=CRIT reason=http_down
monitor=network_monitor host=web-2 status=CRIT reason=http_down
monitor=nfs_mount_monitor host=db-1 status=CRIT reason=ssh_unreachable
monitor=backup_check host=backup-1 status=SKIP reason=missing_targets_file
monitor=backup_check host=backup-2 status=SKIP reason=missing_targets_file
monitor=backup_check host=backup-3 status=SKIP reason=missing_targets_file
monitor=health_monitor host=localhost status=OK
S

out="$(bash "$LM" status --quiet --reasons 3)"
echo "$out" | grep -q '^reason_rollup:$'
echo "$out" | grep -q '^missing_targets_file=3$'
echo "$out" | grep -q '^http_down=2$'
echo "$out" | grep -q '^failed_units=2$'

json_out="$(bash "$LM" status --json --reasons 2)"
printf '%s' "$json_out" | python3 -c 'import json,sys; o=json.load(sys.stdin); rr=o.get("reason_rollup"); assert isinstance(rr,list); assert len(rr)==2; assert rr[0]=={"reason":"missing_targets_file","count":3}; assert rr[1]["count"]==2; assert rr[1]["reason"] in {"http_down","failed_units"}'

without_rollup="$(bash "$LM" status --quiet)"
if echo "$without_rollup" | grep -q '^reason_rollup:$'; then
  echo "unexpected reason_rollup section without --reasons" >&2
  exit 1
fi

echo "status reason rollup ok"
