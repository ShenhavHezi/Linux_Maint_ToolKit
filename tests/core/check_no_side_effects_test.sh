#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

cfgdir="$workdir/missing_cfg"
mkdir -p "$workdir/logs" "$workdir/state" "$workdir/lock"

set +e
LM_CFG_DIR="$cfgdir" LOG_DIR="$workdir/logs" LM_STATE_DIR="$workdir/state" LM_LOCKDIR="$workdir/lock" bash "$LM" check --json >/dev/null 2>&1
rc=$?
set -e

[[ "$rc" -eq 1 || "$rc" -eq 2 || "$rc" -eq 3 ]] || {
  echo "unexpected check rc=$rc" >&2
  exit 1
}

if [[ -d "$cfgdir" ]]; then
  echo "check should not create missing repo config dir" >&2
  exit 1
fi

echo "check no side effects ok"
