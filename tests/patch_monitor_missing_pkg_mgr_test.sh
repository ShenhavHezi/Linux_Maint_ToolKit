#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

export LM_MODE=repo
export LM_LOG_DIR="$ROOT_DIR/.logs"
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
