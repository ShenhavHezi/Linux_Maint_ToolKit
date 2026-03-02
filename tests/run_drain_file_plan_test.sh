#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT
cfg_dir="$workdir/etc"
mkdir -p "$cfg_dir"
printf '%s\n' "host-a" "host-b" > "$cfg_dir/servers.txt"
: > "$cfg_dir/excluded.txt"
: > "$cfg_dir/services.txt"

drain="$workdir/drain.txt"
printf '%s\n' host-b > "$drain"

out="$(LM_CFG_DIR="$cfg_dir" bash "$LM" run --plan --hosts host-a,host-b --drain-file "$drain" 2>/dev/null || true)"
printf '%s\n' "$out" | grep -q '^host-a$' || {
  echo "expected host-a present" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q '^host-b$' && {
  echo "expected host-b drained from plan" >&2
  echo "$out" >&2
  exit 1
}

echo "run drain file plan ok"
