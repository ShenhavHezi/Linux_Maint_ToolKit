#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

export LM_MODE=repo
export LM_LOG_DIR="$ROOT_DIR/.logs"
mkdir -p "$LM_LOG_DIR"

export LM_FORCE_MISSING_DEPS="timeout"

set +e
out="$("$ROOT_DIR"/monitors/nfs_mount_monitor.sh 2>/dev/null)"
rc=$?
set -e

printf '%s
' "$out" | grep -q 'monitor=nfs_mount_monitor'
printf '%s
' "$out" | grep -q 'status=UNKNOWN'
printf '%s
' "$out" | grep -q 'reason=missing_dependency'
[ "$rc" -eq 3 ]

unset LM_FORCE_MISSING_DEPS

echo "nfs dependency detection ok"
