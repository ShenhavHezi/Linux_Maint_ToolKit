#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"
LOG_DIR="$ROOT_DIR/.logs"
SUMMARY_FILE="$LOG_DIR/full_health_monitor_summary_latest.log"
STATUS_FILE="$LOG_DIR/last_status_full"

mkdir -p "$LOG_DIR"

backup_summary=""
backup_status=""
if [[ -f "$SUMMARY_FILE" ]]; then
  backup_summary="$SUMMARY_FILE.bak.$$"
  cp -f "$SUMMARY_FILE" "$backup_summary"
fi
if [[ -f "$STATUS_FILE" ]]; then
  backup_status="$STATUS_FILE.bak.$$"
  cp -f "$STATUS_FILE" "$backup_status"
fi

cleanup() {
  if [[ -n "$backup_summary" && -f "$backup_summary" ]]; then
    mv -f "$backup_summary" "$SUMMARY_FILE"
  else
    rm -f "$SUMMARY_FILE"
  fi
  if [[ -n "$backup_status" && -f "$backup_status" ]]; then
    mv -f "$backup_status" "$STATUS_FILE"
  else
    rm -f "$STATUS_FILE"
  fi
}
trap cleanup EXIT

cat > "$SUMMARY_FILE" <<'SUM'
monitor=a host=h1 status=OK
monitor=b host=h2 status=WARN reason=foo
monitor=c host=h3 status=CRIT reason=bar
monitor=d host=h4 status=UNKNOWN reason=baz
monitor=e host=h5 status=SKIP reason=missing
monitor=f host=h6 status=OK
SUM

cat > "$STATUS_FILE" <<'STAT'
overall=CRIT
exit_code=2
STAT

out="$(bash "$LM" status --prom 2>/dev/null || true)"

printf '%s\n' "$out" | grep -q 'linux_maint_overall_status{status="CRIT"} 1' || {
  echo "status --prom missing overall status" >&2
  echo "$out" >&2
  exit 1
}

printf '%s\n' "$out" | grep -q 'linux_maint_status_count{status="ok"} 2' || {
  echo "status --prom missing OK count" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q 'linux_maint_status_count{status="warn"} 1' || {
  echo "status --prom missing WARN count" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q 'linux_maint_status_count{status="crit"} 1' || {
  echo "status --prom missing CRIT count" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q 'linux_maint_status_count{status="unknown"} 1' || {
  echo "status --prom missing UNKNOWN count" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q 'linux_maint_status_count{status="skip"} 1' || {
  echo "status --prom missing SKIP count" >&2
  echo "$out" >&2
  exit 1
}

echo "status prom ok"
