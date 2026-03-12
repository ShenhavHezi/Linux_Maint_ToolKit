#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
MONITOR="$ROOT_DIR/monitors/preflight_check.sh"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

cfg_dir="$workdir/etc_linux_maint"
state_dir="$workdir/state"
log_dir="$workdir/logs"
mkdir -p "$cfg_dir" "$state_dir" "$log_dir"
: > "$cfg_dir/servers.txt"
: > "$cfg_dir/excluded.txt"
: > "$cfg_dir/services.txt"

set +e
out="$(LM_CFG_DIR="$cfg_dir" LM_STATE_DIR="$state_dir" LOG_DIR="$log_dir" LM_PREFLIGHT_OPT_CMDS='awk sed grep' bash "$MONITOR" 2>&1)"
rc=$?
set -e

if [[ "$rc" -eq 3 ]]; then
  echo "preflight should not fail with UNKNOWN when repo-local paths are writable" >&2
  echo "$out" >&2
  exit 1
fi

if printf '%s\n' "$out" | grep -q 'reason=permission_denied'; then
  echo "preflight still reported permission_denied for repo-local writable paths" >&2
  echo "$out" >&2
  exit 1
fi

printf '%s\n' "$out" | grep -q '^monitor=preflight_check ' || {
  echo "preflight summary missing" >&2
  echo "$out" >&2
  exit 1
}

echo "preflight repo paths ok"
