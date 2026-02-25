#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR="${TMPDIR:-/tmp}"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

cfg="$workdir/etc_linux_maint"
logdir="$workdir/logs"
mkdir -p "$cfg" "$logdir"

printf '%s\n' localhost > "$cfg/servers.txt"
: > "$cfg/excluded.txt"

export LM_CFG_DIR="$cfg"
export LOG_DIR="$logdir"
export SUMMARY_DIR="$logdir"
export LM_STATE_DIR="$workdir/state"
export LM_LOCAL_ONLY=true
export LM_MONITORS="cert_monitor.sh network_monitor.sh ports_baseline_monitor.sh config_drift_monitor.sh user_monitor.sh"

set +e
bash "$ROOT_DIR/run_full_health_monitor.sh" >/dev/null 2>&1
set -e

summary="$logdir/full_health_monitor_summary_latest.log"
[ -f "$summary" ] || { echo "Missing summary: $summary" >&2; exit 1; }

expect_reason() {
  local monitor="$1" reason="$2" missing="$3"
  if ! grep -F "monitor=${monitor} " "$summary" | grep -F " status=SKIP " | grep -F " reason=${reason} " | grep -F " missing=${missing}" >/dev/null; then
    echo "Expected ${monitor} SKIP reason=${reason} missing=${missing}" >&2
    echo "--- summary ---" >&2
    cat "$summary" >&2
    exit 1
  fi
}

expect_reason "cert_monitor" "config_missing" "$cfg/certs.txt"
expect_reason "network_monitor" "config_missing" "$cfg/network_targets.txt"
expect_reason "ports_baseline_monitor" "baseline_missing" "$cfg/ports_baseline.txt"
expect_reason "config_drift_monitor" "config_missing" "$cfg/config_paths.txt"
expect_reason "user_monitor" "baseline_missing" "$cfg/baseline_users.txt,$cfg/baseline_sudoers.txt"

echo "skip gate reasons ok"
