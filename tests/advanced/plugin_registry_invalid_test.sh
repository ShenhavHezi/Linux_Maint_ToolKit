#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

plug_dir="$workdir/plugins"
mkdir -p "$plug_dir/sample_plugin"
printf '%s\n' '{not-json' > "$plug_dir/registry.json"

set +e
list_out="$(LM_PLUGIN_DIR="$plug_dir" bash "$LM" plugin list --json 2>&1)"
list_rc=$?
remove_out="$(LM_PLUGIN_DIR="$plug_dir" bash "$LM" plugin remove sample_plugin 2>&1)"
remove_rc=$?
set -e

if [[ "$list_rc" -ne 2 ]]; then
  echo "expected plugin list invalid registry failure rc=2, got rc=$list_rc" >&2
  echo "$list_out" >&2
  exit 1
fi

JSON_OUT="$list_out" python3 - <<'PY'
import json, os
obj = json.loads(os.environ["JSON_OUT"])
assert obj["plugin_contract_version"] == 1
assert obj["ok"] is False
assert "error" in obj
PY

if [[ "$remove_rc" -ne 2 ]]; then
  echo "expected plugin remove invalid registry failure rc=2, got rc=$remove_rc" >&2
  echo "$remove_out" >&2
  exit 1
fi

[[ -d "$plug_dir/sample_plugin" ]] || {
  echo "plugin remove should not delete plugin directory when registry is corrupt" >&2
  exit 1
}

printf '%s\n' "$remove_out" | grep -q '^ERROR: invalid plugin registry:' || {
  echo "unexpected plugin remove invalid registry output" >&2
  echo "$remove_out" >&2
  exit 1
}

echo "plugin registry invalid ok"
