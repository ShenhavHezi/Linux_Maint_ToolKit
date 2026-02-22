#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"
TMPDIR="${TMPDIR:-/tmp}"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

cfg="$workdir/etc_linux_maint"
mkdir -p "$cfg"

out="$(LM_CFG_DIR="$cfg" bash "$LM" status --no-color 2>/dev/null || true)"

printf '%s\n' "$out" | grep -q '^Expected SKIPs (missing optional config):' || {
  echo "status expected SKIPs banner missing" >&2
  echo "$out" >&2
  exit 1
}

echo "status expected skips banner ok"
