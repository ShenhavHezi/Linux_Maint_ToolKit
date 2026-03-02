#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

cfg_dir="$workdir/etc"
mkdir -p "$cfg_dir"
printf '%s\n' localhost > "$cfg_dir/servers.txt"

set +e
out_fail="$(LM_CFG_DIR="$cfg_dir" LOG_DIR="$workdir/logs" LM_STATE_DIR="$workdir/state" LM_LOCKDIR="$workdir/lock" bash "$LM" self-check --strict 2>&1)"
rc_fail=$?
set -e

[[ "$rc_fail" -eq 2 ]] || {
  echo "expected strict failure rc=2, got rc=$rc_fail" >&2
  echo "$out_fail" >&2
  exit 1
}

: > "$cfg_dir/excluded.txt"
: > "$cfg_dir/services.txt"
mkdir -p "$workdir/logs" "$workdir/state" "$workdir/lock"

LM_CFG_DIR="$cfg_dir" LOG_DIR="$workdir/logs" LM_STATE_DIR="$workdir/state" LM_LOCKDIR="$workdir/lock" bash "$LM" self-check --strict >/dev/null

echo "self-check strict ok"
