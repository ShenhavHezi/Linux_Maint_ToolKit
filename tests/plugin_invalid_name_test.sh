#!/usr/bin/env bash
set -euo pipefail

TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

plug_dir="$workdir/plugins"
valid_src="$workdir/valid-plugin"
manifest_bad_src="$workdir/manifest-bad-plugin"
mkdir -p "$plug_dir" "$valid_src" "$manifest_bad_src"

cat > "$valid_src/plugin.json" <<'JSON'
{
  "name": "valid_plugin",
  "version": "0.1.0"
}
JSON

cat > "$manifest_bad_src/plugin.json" <<'JSON'
{
  "name": "../../escape",
  "version": "0.1.0"
}
JSON

set +e
out="$(LM_PLUGIN_DIR="$plug_dir" bash "$LM" plugin install "$manifest_bad_src" 2>&1)"
rc=$?
set -e
[[ "$rc" -eq 2 ]] || {
  echo "plugin install accepted invalid manifest name" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q 'invalid plugin name' || {
  echo "plugin install did not explain invalid manifest name" >&2
  echo "$out" >&2
  exit 1
}
[[ ! -e "$workdir/escape" ]] || {
  echo "plugin install escaped plugin root via manifest name" >&2
  exit 1
}

set +e
out="$(LM_PLUGIN_DIR="$plug_dir" bash "$LM" plugin install "$valid_src" --name '../escape' 2>&1)"
rc=$?
set -e
[[ "$rc" -eq 2 ]] || {
  echo "plugin install accepted invalid --name override" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q 'Plugin names must match' || {
  echo "plugin install did not explain invalid --name override" >&2
  echo "$out" >&2
  exit 1
}
[[ ! -e "$workdir/escape" ]] || {
  echo "plugin install escaped plugin root via --name override" >&2
  exit 1
}

for sub in update verify remove; do
  set +e
  out="$(LM_PLUGIN_DIR="$plug_dir" bash "$LM" plugin "$sub" '../../escape' 2>&1)"
  rc=$?
  set -e
  [[ "$rc" -eq 2 ]] || {
    echo "plugin $sub accepted invalid name" >&2
    echo "$out" >&2
    exit 1
  }
  printf '%s\n' "$out" | grep -q 'invalid plugin name' || {
    echo "plugin $sub did not explain invalid name" >&2
    echo "$out" >&2
    exit 1
  }
done

echo "plugin invalid name ok"
