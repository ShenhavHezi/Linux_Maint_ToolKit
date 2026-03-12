#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

cfg="$workdir/etc_linux_maint"
mkdir -p "$cfg" "$workdir/state" "$workdir/lock" "$workdir/logs"
printf '%s\n' localhost > "$cfg/servers.txt"
printf '%s\n' localhost > "$cfg/excluded.txt"
printf '%s\n' sshd > "$cfg/services.txt"

set +e
LM_CFG_DIR="$cfg" LM_STATE_DIR="$workdir/state" LM_LOCKDIR="$workdir/lock" LOG_DIR="$workdir/logs" LM_PREFLIGHT_OPT_CMDS='awk sed grep df ssh' bash "$LM" check >/dev/null 2>&1
rc_text=$?
LM_CFG_DIR="$cfg" LM_STATE_DIR="$workdir/state" LM_LOCKDIR="$workdir/lock" LOG_DIR="$workdir/logs" LM_PREFLIGHT_OPT_CMDS='awk sed grep df ssh' bash "$LM" check --json >/dev/null 2>&1
rc_json=$?
set -e

[[ "$rc_text" -eq 1 ]] || {
  echo "expected check rc=1 for warn-only input, got rc=$rc_text" >&2
  exit 1
}
[[ "$rc_json" -eq 1 ]] || {
  echo "expected check --json rc=1 for warn-only input, got rc=$rc_json" >&2
  exit 1
}

echo "check exit code ok"
