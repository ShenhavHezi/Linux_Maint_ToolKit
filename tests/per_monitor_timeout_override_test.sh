#!/usr/bin/env bash
set -euo pipefail

# Test: per-monitor timeout overrides are honored by the wrapper.
# Use a monitor that should exceed 1s in most environments.

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}" )/.." && pwd)"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

export LM_CFG_DIR="$workdir/etc_linux_maint"
mkdir -p "$LM_CFG_DIR"

printf '%s\n' localhost > "$LM_CFG_DIR/servers.txt"
: > "$LM_CFG_DIR/excluded.txt"

cat > "$LM_CFG_DIR/monitor_timeouts.conf" <<'CONF'
disk_trend_monitor=1
CONF

export SCRIPTS_DIR="$REPO_DIR/monitors"
export LOG_DIR="$workdir/logs"
export SUMMARY_DIR="$workdir/logs"

set +e
"$REPO_DIR/run_full_health_monitor.sh" >/dev/null 2>&1
set -e

summary="$workdir/logs/full_health_monitor_summary_latest.log"
if ! grep -q "monitor=disk_trend_monitor .*status=UNKNOWN .*reason=timeout" "$summary"; then
  echo "Expected disk_trend_monitor to have reason=timeout in summary." >&2
  echo "--- summary ---" >&2
  cat "$summary" >&2 || true
  exit 1
fi
