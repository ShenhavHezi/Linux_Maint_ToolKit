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
monitor=network_monitor host=web-1 status=CRIT reason=http_down
monitor=health_monitor host=localhost status=OK
S

out=$(bash "$LM" status --quiet)

# Must include totals + problems
echo "$out" | grep -q '^totals: ' || { echo "Missing totals" >&2; exit 1; }
echo "$out" | grep -q '^problems' || { echo "Missing problems header" >&2; exit 1; }

# Must NOT include verbose headers
if echo "$out" | grep -q '^=== Mode ==='; then
  echo "Found Mode header in --quiet output" >&2
  exit 1
fi

if echo "$out" | grep -q 'Installed paths'; then
  echo "Found Installed paths in --quiet output" >&2
  exit 1
fi

echo "status --quiet ok"
