#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"
LOG_DIR="$ROOT_DIR/.logs"
mkdir -p "$LOG_DIR"

f1="$LOG_DIR/full_health_monitor_summary_2099-01-01_010101.log"
f2="$LOG_DIR/full_health_monitor_summary_2099-01-02_010101.log"
trap 'rm -f "$f1" "$f2"' EXIT

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

out="$(bash "$LM" trend --last 2)"
echo "$out" | grep -q '^trend_runs=2 '
echo "$out" | grep -q 'totals: CRIT=1 WARN=2 UNKNOWN=1 SKIP=1 OK=1'
echo "$out" | grep -q '^failed_units=2$'

ajson="$(bash "$LM" trend --last 2 --json)"
printf '%s' "$ajson" | python3 -c 'import json,sys; o=json.load(sys.stdin); assert len(o["runs"])==2; assert o["totals"]["WARN"]==2; assert o["totals"]["CRIT"]==1; assert o["totals"]["UNKNOWN"]==1; assert o["totals"]["SKIP"]==1; assert o["totals"]["OK"]==1; assert o["reasons"][0]=={"reason":"failed_units","count":2}'

set +e
bad="$(bash "$LM" trend --last 0 2>&1)"
rc=$?
set -e
if [[ "$rc" -ne 2 ]]; then
  echo "expected rc=2 for invalid --last, got $rc" >&2
  exit 1
fi
echo "$bad" | grep -q 'ERROR: --last must be a positive integer'

echo "trend command ok"
