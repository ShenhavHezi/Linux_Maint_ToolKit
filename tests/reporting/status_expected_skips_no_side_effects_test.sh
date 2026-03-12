#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

cfgdir="$workdir/missing_cfg"

LM_CFG_DIR="$cfgdir" bash "$LM" status --expected-skips --no-color >/dev/null

if [[ -d "$cfgdir" ]]; then
  echo "status --expected-skips should not create missing repo config dir" >&2
  exit 1
fi

echo "status expected skips no side effects ok"
