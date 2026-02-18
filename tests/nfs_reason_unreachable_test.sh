#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

export LM_MODE=repo
export LINUX_MAINT_LIB="$ROOT_DIR/lib/linux_maint.sh"
export LM_LOG_DIR="$workdir/logs"
export LM_LOGFILE="$workdir/nfs.log"
export LM_STATE_DIR="$workdir/state"
export LM_SERVERLIST="$workdir/servers.txt"
export LM_EXCLUDED="$workdir/excluded.txt"
export LM_SSH_OPTS='-o BatchMode=yes -o ConnectTimeout=1 -o ConnectionAttempts=1'
mkdir -p "$LM_LOG_DIR" "$LM_STATE_DIR"
printf 'no-such-host.invalid\n' > "$LM_SERVERLIST"
: > "$LM_EXCLUDED"

set +e
out="$(timeout 20s "$ROOT_DIR/monitors/nfs_mount_monitor.sh" 2>/dev/null)"
rc=$?
set -e

printf '%s\n' "$out" | grep -q 'monitor=nfs_mount_monitor'
printf '%s\n' "$out" | grep -q 'status=CRIT'
printf '%s\n' "$out" | grep -q 'reason=ssh_unreachable'
[ "$rc" -eq 0 ]

echo "nfs reason unreachable ok"
