#!/usr/bin/env bash
set -euo pipefail

TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

LOG_DIR="$workdir/logs"
mkdir -p "$LOG_DIR"

SUMMARY_FILE="$LOG_DIR/full_health_monitor_summary_latest.log"
STATUS_FILE="$LOG_DIR/last_status_full"

cat > "$STATUS_FILE" <<'S'
status=warn
timestamp=2026-02-17T00:00:00+00:00
S

cat > "$SUMMARY_FILE" <<'S'
monitor=service_monitor host=web-1 status=WARN reason=failed_units
monitor=network_monitor host=web-1 status=CRIT reason=http_down
monitor=health_monitor host=localhost status=OK
S

out=$(LOG_DIR="$LOG_DIR" bash "$LM" status --quiet)

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
