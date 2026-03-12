#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

plugins_json="$workdir/plugins.json"
cat > "$plugins_json" <<'JSON'
[
  {
    "name": "schema_plugin",
    "version": "1.0.0",
    "source": "/tmp/schema_plugin",
    "trust": "verified"
  }
]
JSON
digest="$(sha256sum "$plugins_json" | awk '{print $1}')"
index_file="$workdir/index.json"
cat > "$index_file" <<JSON
{
  "plugins": [
    {
      "name": "schema_plugin",
      "version": "1.0.0",
      "source": "/tmp/schema_plugin",
      "trust": "verified"
    }
  ],
  "attestation": {
    "type": "sha256",
    "target": "plugins.json",
    "value": "$digest"
  }
}
JSON

json_out="$(bash "$LM" plugin verify-index --index "$index_file" --json --strict)"
printf '%s' "$json_out" | python3 "$ROOT_DIR/tools/json_schema_validate.py" "$ROOT_DIR/docs/schemas/plugin_verify_index.json"

echo "plugin verify-index json schema ok"
