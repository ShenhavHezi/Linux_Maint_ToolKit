#!/usr/bin/env bash
set -euo pipefail

# Run wrapper once (best-effort) to produce a repo log, then lint latest.
# This test is intentionally tolerant: wrapper may return non-zero.

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${LOG_DIR:-$REPO_ROOT/.logs}"
SUMMARY="$LOG_DIR/full_health_monitor_summary_latest.log"
LOG="$LOG_DIR/full_health_monitor_latest.log"

mkdir -p "$LOG_DIR" || true

# best effort
(LOG_DIR="$LOG_DIR" "$REPO_ROOT/run_full_health_monitor.sh" >/dev/null 2>&1 || true)



TARGET=""
if [[ -f "$SUMMARY" ]]; then
  TARGET="$SUMMARY"
elif [[ -f "$LOG" ]]; then
  TARGET="$LOG"
else
  echo "ERROR: summary/log not found in LOG_DIR=$LOG_DIR" >&2
  echo "Tried: $SUMMARY" >&2
  echo "Tried: $LOG" >&2
  echo "Directory listing:" >&2
  ls -la "$LOG_DIR" >&2 || true
  exit 2
fi

exec python3 "$REPO_ROOT/tests/summary_contract_lint.py" "$TARGET"
