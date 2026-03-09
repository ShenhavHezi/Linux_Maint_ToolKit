#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

export LM_MODE=repo
export LINUX_MAINT_LIB="$ROOT_DIR/lib/linux_maint.sh"
export LM_LOG_DIR="$ROOT_DIR/.logs"
mkdir -p "$LM_LOG_DIR"
export LOG_DIR="$workdir/logs"
export LM_STATE_DIR="$workdir/state"
mkdir -p "$LOG_DIR" "$LM_STATE_DIR"

export LM_FORCE_MISSING_DEPS="ssh"

set +e
out="$("$ROOT_DIR"/monitors/preflight_check.sh 2>/dev/null)"
rc=$?
set -e

printf "%s\n" "$out" | grep -q "monitor=preflight_check"
printf "%s\n" "$out" | grep -q "status=UNKNOWN"
printf "%s\n" "$out" | grep -q "reason=missing_dependency"
[ "$(printf "%s\n" "$out" | grep -c '^monitor=' || true)" -eq 1 ]
[ "$rc" -eq 3 ]

unset LM_FORCE_MISSING_DEPS
echo "preflight missing ssh ok"
