#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

cfg_dir="$workdir/etc_linux_maint"
log_dir="$workdir/logs"
mkdir -p "$cfg_dir" "$log_dir"

# Minimal required files so wrapper can run.
printf 'localhost\n' > "$cfg_dir/servers.txt"
: > "$cfg_dir/excluded.txt"
cat > "$cfg_dir/services.txt" <<'SVC'
sshd
SVC

set +e
LM_MONITORS="network_monitor.sh" \
LM_CFG_DIR="$cfg_dir" \
LOG_DIR="$log_dir" \
SUMMARY_DIR="$log_dir" \
bash "$ROOT_DIR/run_full_health_monitor.sh" >/dev/null 2>&1
rc=$?
set -e

if [[ "$rc" -ne 0 ]]; then
  echo "expected wrapper rc=0 when network_monitor is skipped, got rc=$rc" >&2
  exit 1
fi

latest_log="$(ls -1t "$log_dir"/full_health_monitor_*.log | head -n1)"
if ! grep -q "^monitor=network_monitor host=all status=SKIP .*reason=missing:${cfg_dir}/network_targets.txt" "$latest_log"; then
  echo "missing expected SKIP summary for network_monitor" >&2
  tail -n 120 "$latest_log" >&2 || true
  exit 1
fi

echo "wrapper network targets skip ok"
