#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REAL_LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

prefix="$workdir/prefix"
mkdir -p "$prefix/bin" "$prefix/lib" "$prefix/share/linux_maint/plugins"
cp "$REAL_LM" "$prefix/bin/linux-maint"
chmod +x "$prefix/bin/linux-maint"
for support_lib in linux_maint_runtime.sh linux_maint_admin.sh linux_maint_help.sh linux_maint_tui.sh linux_maint_reporting.sh linux_maint_advanced.sh; do
  cp "$ROOT_DIR/lib/$support_lib" "$prefix/lib/$support_lib"
done

cat > "$prefix/share/linux_maint/plugins/index.json" <<'JSON'
{
  "plugins": [
    {
      "name": "packaged_plugin",
      "version": "1.2.3",
      "source": "/tmp/packaged-plugin",
      "description": "packaged index entry"
    }
  ]
}
JSON

json_out="$(bash "$prefix/bin/linux-maint" plugin search --json 2>/dev/null)"

JSON_OUT="$json_out" python3 - <<'PY'
import json, os
obj = json.loads(os.environ["JSON_OUT"])
assert obj["plugin_contract_version"] == 1
assert obj["index"].endswith("/share/linux_maint/plugins/index.json")
plugins = obj.get("plugins") or []
assert len(plugins) == 1
assert plugins[0]["name"] == "packaged_plugin"
PY

echo "plugin installed default index ok"
