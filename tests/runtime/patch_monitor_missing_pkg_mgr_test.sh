#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

export LM_MODE=repo
export LINUX_MAINT_LIB="$ROOT_DIR/lib/linux_maint.sh"
export LM_LOG_DIR="$ROOT_DIR/.logs"
export LM_LOCKDIR="$workdir"
export LM_LOGFILE="$workdir/patch_monitor.log"
mkdir -p "$LM_LOG_DIR"

export LM_FORCE_MISSING_DEPS="apt-get,dnf,yum,zypper"

set +e
out="$("$ROOT_DIR"/monitors/patch_monitor.sh 2>/dev/null)"
rc=$?
set -e

printf '%s
' "$out" | grep -q 'monitor=patch_monitor'
printf '%s
' "$out" | grep -q 'status=SKIP'
printf '%s
' "$out" | grep -q 'reason=unsupported_pkg_mgr'
printf '%s
' "$out" | grep -q 'mgr=unknown'
[ "$rc" -eq 0 ]

unset LM_FORCE_MISSING_DEPS

echo "patch monitor missing pkg mgr ok"
