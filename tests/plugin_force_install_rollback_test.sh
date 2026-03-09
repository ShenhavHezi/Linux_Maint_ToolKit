#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

plug_dir="$workdir/plugins"
good_src="$workdir/sample-plugin-good"
bad_src="$workdir/sample-plugin-bad"
mkdir -p "$good_src" "$bad_src"

cat > "$good_src/plugin.json" <<'P'
{
  "name": "sample_plugin",
  "version": "0.1.0",
  "description": "sample plugin"
}
P

LM_PLUGIN_DIR="$plug_dir" bash "$LM" plugin install "$good_src" >/dev/null

cat > "$bad_src/plugin.json" <<'P'
{
  "name": "sample_plugin",
  "version": "0.2.0",
  "description": "broken replacement"
}
P
ln -s "$bad_src/does-not-exist" "$bad_src/broken-link"

set +e
LM_PLUGIN_DIR="$plug_dir" bash "$LM" plugin install "$bad_src" --force >/dev/null 2>&1
rc=$?
set -e

[ "$rc" -ne 0 ] || {
  echo "expected forced install from broken source to fail" >&2
  exit 1
}

list_json="$(LM_PLUGIN_DIR="$plug_dir" bash "$LM" plugin list --json 2>/dev/null || true)"
printf '%s\n' "$list_json" | grep -q '"version": "0.1.0"' || {
  echo "failed force install should preserve existing plugin registry entry" >&2
  echo "$list_json" >&2
  exit 1
}

test -f "$plug_dir/sample_plugin/plugin.json" || {
  echo "failed force install removed existing plugin files" >&2
  exit 1
}

echo "plugin force install rollback ok"
