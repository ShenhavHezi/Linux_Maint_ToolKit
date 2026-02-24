#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$ROOT_DIR/lib/linux_maint.sh"

tmp_root="$(mktemp -d -p "$TMPDIR" lm_singleton.XXXXXX)"

lock_dir="$tmp_root/locks"
mkdir -p "$lock_dir"
lock_file="$lock_dir/distributed_health_monitor.lock"

cleanup() {
  kill "${holder:-}" 2>/dev/null || true
  wait "${holder:-}" 2>/dev/null || true
  rm -rf "$tmp_root"
}
trap cleanup EXIT

flock -n "$lock_file" -c "sleep 5" &
holder=$!
sleep 0.1

out="$(LM_LOCKDIR="$lock_dir" LM_SUMMARY_STRICT=1 LM_LOGFILE="$tmp_root/linux_maint.log" \
  bash -c '. "$0"; lm_require_singleton "distributed_health_monitor" "health_monitor" || true' "$LIB")"

printf '%s\n' "$out" | grep -q 'monitor=health_monitor' || { echo "missing monitor name in summary" >&2; echo "$out" >&2; exit 1; }
printf '%s\n' "$out" | grep -q 'host=runner' || { echo "expected host=runner in summary" >&2; echo "$out" >&2; exit 1; }
printf '%s\n' "$out" | grep -q 'status=SKIP' || { echo "expected status=SKIP in summary" >&2; echo "$out" >&2; exit 1; }
printf '%s\n' "$out" | grep -q 'reason=already_running' || { echo "expected reason=already_running in summary" >&2; echo "$out" >&2; exit 1; }

echo "singleton skip summary ok"
