#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

plug_dir="$workdir/plugins"
plug_src="$workdir/sample-plugin"
mkdir -p "$plug_dir/existing_plugin" "$plug_src"

cat > "$plug_dir/existing_plugin/plugin.json" <<'JSON'
{
  "name": "existing_plugin",
  "version": "0.1.0"
}
JSON

cat > "$plug_src/plugin.json" <<'JSON'
{
  "name": "existing_plugin",
  "version": "0.2.0",
  "description": "updated plugin"
}
JSON

printf '%s\n' '{not-json' > "$plug_dir/registry.json"
registry_before="$(cat "$plug_dir/registry.json")"

set +e
install_out="$(LM_PLUGIN_DIR="$plug_dir" bash "$LM" plugin install "$plug_src" --name fresh_plugin 2>&1)"
install_rc=$?
update_out="$(LM_PLUGIN_DIR="$plug_dir" bash "$LM" plugin update existing_plugin --source "$plug_src" 2>&1)"
update_rc=$?
set -e

if [[ "$install_rc" -ne 2 ]]; then
  echo "expected plugin install invalid registry failure rc=2, got rc=$install_rc" >&2
  echo "$install_out" >&2
  exit 1
fi

if [[ "$update_rc" -ne 2 ]]; then
  echo "expected plugin update invalid registry failure rc=2, got rc=$update_rc" >&2
  echo "$update_out" >&2
  exit 1
fi

printf '%s\n' "$install_out" | grep -q '^ERROR: invalid plugin registry:' || {
  echo "unexpected plugin install invalid registry output" >&2
  echo "$install_out" >&2
  exit 1
}

printf '%s\n' "$update_out" | grep -q '^ERROR: invalid plugin registry:' || {
  echo "unexpected plugin update invalid registry output" >&2
  echo "$update_out" >&2
  exit 1
}

[[ ! -d "$plug_dir/fresh_plugin" ]] || {
  echo "plugin install should not create target directory when registry is corrupt" >&2
  exit 1
}

grep -q '"version": "0.1.0"' "$plug_dir/existing_plugin/plugin.json" || {
  echo "plugin update should preserve existing plugin files when registry is corrupt" >&2
  cat "$plug_dir/existing_plugin/plugin.json" >&2
  exit 1
}

[[ "$(cat "$plug_dir/registry.json")" == "$registry_before" ]] || {
  echo "plugin commands should not rewrite corrupt registry" >&2
  cat "$plug_dir/registry.json" >&2
  exit 1
}

echo "plugin write invalid registry ok"
