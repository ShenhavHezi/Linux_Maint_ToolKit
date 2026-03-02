#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

plug_src="$workdir/signed-plugin"
plug_dir="$workdir/plugins"
mkdir -p "$plug_src"
printf 'payload-v1\n' > "$plug_src/payload.txt"
sig="$(sha256sum "$plug_src/payload.txt" | awk '{print $1}')"
cat > "$plug_src/plugin.json" <<P
{
  "name": "schema_signed_plugin",
  "version": "0.1.0",
  "description": "signed plugin",
  "signature": {
    "type": "sha256",
    "target": "payload.txt",
    "value": "$sig"
  }
}
P

LM_PLUGIN_DIR="$plug_dir" bash "$LM" plugin install "$plug_src" >/dev/null
json_out="$(LM_PLUGIN_DIR="$plug_dir" bash "$LM" plugin verify schema_signed_plugin --json)"
printf '%s' "$json_out" | python3 "$ROOT_DIR/tools/json_schema_validate.py" "$ROOT_DIR/docs/schemas/plugin_verify.json"

echo "plugin verify json schema ok"
