#!/usr/bin/env bash
set -euo pipefail

TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

audit_file="$workdir/audit.log"
plug_src="$workdir/sample-plugin"
plug_dir="$workdir/plugins"
mkdir -p "$plug_src"
cat > "$plug_src/plugin.json" <<'P'
{
  "name": "sample_plugin",
  "version": "0.1.0",
  "description": "sample plugin"
}
P

LM_AUDIT_LOG="$audit_file" LM_PLUGIN_DIR="$plug_dir" bash "$LM" plugin install "$plug_src" >/dev/null
json_out="$(LM_AUDIT_LOG="$audit_file" bash "$LM" audit-log --json --last 5)"
printf '%s' "$json_out" | python3 "$ROOT_DIR/tools/json_schema_validate.py" "$ROOT_DIR/docs/schemas/audit_log.json"

echo "audit-log json schema ok"
