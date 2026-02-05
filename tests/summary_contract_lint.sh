#!/usr/bin/env bash
set -euo pipefail

# Run wrapper once (best-effort) to produce a repo log, then lint latest.
# This test is intentionally tolerant: wrapper may return non-zero.

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${LOG_DIR:-$REPO_ROOT/.logs}"
export LM_LOCKDIR="${LM_LOCKDIR:-/tmp}"
SUMMARY="$LOG_DIR/full_health_monitor_summary_latest.log"
LOG="$LOG_DIR/full_health_monitor_latest.log"

mkdir -p "$LOG_DIR" || true

# best effort
# best effort (capture output for CI diagnostics)
WRAPPER_OUT="$LOG_DIR/wrapper_ci_debug.out"
(LOG_DIR="$LOG_DIR" "$REPO_ROOT/run_full_health_monitor.sh" >"$WRAPPER_OUT" 2>&1 || true)



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
  echo "Wrapper output tail:" >&2
  tail -n 200 "$WRAPPER_OUT" >&2 || true
  exit 2
fi

exec python3 "$REPO_ROOT/tests/summary_contract_lint.py" "$TARGET"
