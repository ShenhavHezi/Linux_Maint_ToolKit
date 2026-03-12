#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

plug_dir="$workdir/plugins"
src="$workdir/bad-plugin"
mkdir -p "$plug_dir" "$src"

cat > "$src/plugin.json" <<'JSON'
{not-json
JSON

set +e
install_out="$(LM_PLUGIN_DIR="$plug_dir" bash "$LM" plugin install "$src" 2>&1)"
install_rc=$?
set -e

if [[ "$install_rc" -ne 2 ]]; then
  echo "expected plugin install invalid manifest rc=2, got rc=$install_rc" >&2
  echo "$install_out" >&2
  exit 1
fi

printf '%s\n' "$install_out" | grep -q '^ERROR: invalid plugin manifest:' || {
  echo "unexpected plugin install invalid manifest output" >&2
  echo "$install_out" >&2
  exit 1
}

[[ ! -d "$plug_dir/bad-plugin" ]] || {
  echo "plugin install should not create destination for invalid manifest" >&2
  exit 1
}

index_file="$workdir/index.json"
cat > "$index_file" <<JSON
{
  "plugins": [
    {
      "name": "bad-plugin",
      "version": "1.0.0",
      "source": "$src",
      "trust": "community"
    }
  ]
}
JSON

set +e
update_out="$(LM_PLUGIN_DIR="$plug_dir" bash "$LM" plugin update bad-plugin --index "$index_file" 2>&1)"
update_rc=$?
set -e

if [[ "$update_rc" -ne 2 ]]; then
  echo "expected plugin update invalid manifest rc=2, got rc=$update_rc" >&2
  echo "$update_out" >&2
  exit 1
fi

printf '%s\n' "$update_out" | grep -q '^ERROR: invalid plugin manifest:' || {
  echo "unexpected plugin update invalid manifest output" >&2
  echo "$update_out" >&2
  exit 1
}

echo "plugin install invalid manifest ok"
