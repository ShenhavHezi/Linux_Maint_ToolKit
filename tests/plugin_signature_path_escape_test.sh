#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

plug_src="$workdir/escape-plugin"
plug_dir="$workdir/plugins"
mkdir -p "$plug_src"
printf 'outside\n' > "$workdir/outside.txt"

cat > "$plug_src/plugin.json" <<'JSON'
{
  "name": "escape_plugin",
  "version": "0.1.0",
  "signature": {
    "type": "sha256",
    "target": "../outside.txt",
    "value": "deadbeef"
  }
}
JSON

LM_PLUGIN_DIR="$plug_dir" bash "$LM" plugin install "$plug_src" >/dev/null

set +e
json_out="$(LM_PLUGIN_DIR="$plug_dir" bash "$LM" plugin verify escape_plugin --json 2>&1)"
rc=$?
set -e

[[ "$rc" -eq 2 ]] || {
  echo "expected plugin verify rc=2 for escaping signature target, got rc=$rc" >&2
  echo "$json_out" >&2
  exit 1
}

printf '%s\n' "$json_out" | grep -q 'signature target escapes plugin dir' || {
  echo "expected escape warning in plugin verify output" >&2
  echo "$json_out" >&2
  exit 1
}

echo "plugin signature path escape ok"
