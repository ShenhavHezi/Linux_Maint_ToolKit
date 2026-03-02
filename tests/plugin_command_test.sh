#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

plug_src="$workdir/sample-plugin"
mkdir -p "$plug_src"
cat > "$plug_src/plugin.json" <<'P'
{
  "name": "sample_plugin",
  "version": "0.1.0",
  "description": "sample plugin"
}
P

plug_dir="$workdir/plugins"

LM_PLUGIN_DIR="$plug_dir" bash "$LM" plugin install "$plug_src" >/dev/null

list_json="$(LM_PLUGIN_DIR="$plug_dir" bash "$LM" plugin list --json 2>/dev/null || true)"
printf '%s\n' "$list_json" | grep -q '"sample_plugin"' || {
  echo "plugin list missing installed plugin" >&2
  echo "$list_json" >&2
  exit 1
}

LM_PLUGIN_DIR="$plug_dir" bash "$LM" plugin verify sample_plugin >/dev/null

LM_PLUGIN_DIR="$plug_dir" bash "$LM" plugin remove sample_plugin >/dev/null

list_json2="$(LM_PLUGIN_DIR="$plug_dir" bash "$LM" plugin list --json 2>/dev/null || true)"
printf '%s\n' "$list_json2" | grep -q '"plugins": \[\]' || {
  echo "plugin remove failed" >&2
  echo "$list_json2" >&2
  exit 1
}

echo "plugin command ok"
