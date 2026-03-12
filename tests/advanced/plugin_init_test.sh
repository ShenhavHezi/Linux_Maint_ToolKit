#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

bash "$LM" plugin init my_plugin --out "$workdir" >/dev/null

[[ -f "$workdir/my_plugin/plugin.json" ]] || {
  echo "plugin.json missing" >&2
  exit 1
}
[[ -f "$workdir/my_plugin/README.md" ]] || {
  echo "README missing" >&2
  exit 1
}

grep -q '"name": "my_plugin"' "$workdir/my_plugin/plugin.json" || {
  echo "plugin scaffold has wrong name" >&2
  cat "$workdir/my_plugin/plugin.json" >&2
  exit 1
}

echo "plugin init ok"
