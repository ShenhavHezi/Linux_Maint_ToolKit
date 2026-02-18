#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"
LOG_DIR="$ROOT_DIR/.logs"
mkdir -p "$LOG_DIR"
mkdir -p "$TMPDIR"

workdir="$(mktemp -d -p "$TMPDIR")"
stash="$workdir/stash"
mkdir -p "$stash"

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
  rm -f "$LOG_DIR"/full_health_monitor_summary_2020-01-01_000000.log "$LOG_DIR"/full_health_monitor_summary_2099-12-31_000000.log
  if [[ -d "$stash" ]]; then
    shopt -s nullglob
    for f in "$stash"/*; do
      mv "$f" "$LOG_DIR"/ 2>/dev/null || true
    done
    shopt -u nullglob
  fi
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
  rm -rf "$workdir"
}
trap cleanup EXIT

# Isolate this test from existing summary history.
shopt -s nullglob
for f in "$LOG_DIR"/full_health_monitor_summary_[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_[0-9][0-9][0-9][0-9][0-9][0-9].log; do
  mv "$f" "$stash"/ 2>/dev/null || true
done
shopt -u nullglob

cat > "$STATUS_FILE" <<'S'
status=warn
timestamp=2099-12-31T00:00:00+00:00
S

cat > "$LOG_DIR/full_health_monitor_summary_2020-01-01_000000.log" <<'S'
monitor=network_monitor host=old status=CRIT reason=old_failure
S

cat > "$LOG_DIR/full_health_monitor_summary_2099-12-31_000000.log" <<'S'
monitor=service_monitor host=new status=WARN reason=new_failure
S

cp "$LOG_DIR/full_health_monitor_summary_2099-12-31_000000.log" "$SUMMARY_FILE"

out="$(bash "$LM" status --quiet --since 1d)"
echo "$out" | grep -q 'WARN service_monitor host=new reason=new_failure'
if echo "$out" | grep -q 'old_failure'; then
  echo "unexpected old entry in --since output" >&2
  exit 1
fi

json_out="$(bash "$LM" status --json --since 1d)"
printf '%s' "$json_out" | python3 -c 'import json,sys; o=json.load(sys.stdin); probs=o.get("problems",[]); reasons={p.get("reason") for p in probs if "reason" in p}; assert "new_failure" in reasons; assert "old_failure" not in reasons'

set +e
bad="$(bash "$LM" status --since abc 2>&1)"
rc=$?
set -e
if [[ "$rc" -ne 2 ]]; then
  echo "expected rc=2 for invalid --since, got $rc" >&2
  exit 1
fi
echo "$bad" | grep -q "ERROR: invalid --since"

echo "status since ok"
