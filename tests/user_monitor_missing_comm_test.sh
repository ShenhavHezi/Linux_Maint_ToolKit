#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

export LM_MODE=repo
export LM_LOG_DIR="$ROOT_DIR/.logs"
mkdir -p "$LM_LOG_DIR"

export LM_FORCE_MISSING_DEPS="comm"

set +e
out="$("$ROOT_DIR"/monitors/user_monitor.sh 2>/dev/null)"
rc=$?
set -e

printf '%s
' "$out" | grep -q 'monitor=user_monitor'
printf '%s
' "$out" | grep -q 'status=UNKNOWN'
printf '%s
' "$out" | grep -q 'reason=missing_dependency'
[ "$rc" -eq 3 ]

unset LM_FORCE_MISSING_DEPS

echo "user monitor missing comm ok"
