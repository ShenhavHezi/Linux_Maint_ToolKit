#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

cfg="$workdir/etc_linux_maint"
mkdir -p "$cfg"
printf '%s\n' localhost > "$cfg/servers.txt"
: > "$cfg/excluded.txt"

set +e
out="$(LM_CFG_DIR="$cfg" LM_SERVERLIST="$cfg/servers.txt" LM_EXCLUDED="$cfg/excluded.txt" LM_LOCAL_ONLY=true LM_PROGRESS=1 LM_PROGRESS_FORCE=1 LM_PROGRESS_MODE=plain bash "$LM" run --only health_monitor --progress 2>&1)"
rc=$?
set -e

if [[ "$rc" -ne 0 ]]; then
  echo "run --only health_monitor failed rc=$rc" >&2
  echo "$out" >&2
  exit 1
fi

printf '%s\n' "$out" | grep -q 'DONE 100%' || {
  echo "progress completion marker missing" >&2
  echo "$out" >&2
  exit 1
}

echo "run only progress output ok"
