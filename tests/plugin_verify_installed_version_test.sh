#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REAL_LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

prefix="$workdir/prefix"
plug_dir="$workdir/plugins"
mkdir -p "$prefix/bin" "$prefix/lib" "$prefix/share/linux_maint" "$plug_dir/version_locked"
cp "$REAL_LM" "$prefix/bin/linux-maint"
chmod +x "$prefix/bin/linux-maint"
for support_lib in linux_maint_runtime.sh linux_maint_admin.sh linux_maint_help.sh; do
  cp "$ROOT_DIR/lib/$support_lib" "$prefix/lib/$support_lib"
done

printf '%s\n' '0.3.3' > "$prefix/share/linux_maint/VERSION"

cat > "$plug_dir/version_locked/plugin.json" <<'JSON'
{
  "name": "version_locked",
  "version": "1.0.0",
  "compatibility": {
    "min_cli_version": "9.9.9"
  }
}
JSON

cat > "$plug_dir/registry.json" <<'JSON'
{
  "plugins": [
    {
      "name": "version_locked",
      "version": "1.0.0",
      "source": "/tmp/version_locked"
    }
  ]
}
JSON

set +e
json_out="$(PREFIX="$prefix" LM_PLUGIN_DIR="$plug_dir" bash "$prefix/bin/linux-maint" plugin verify version_locked --json 2>&1)"
rc=$?
set -e

if [[ "$rc" -ne 2 ]]; then
  echo "expected installed-mode plugin verify compatibility failure rc=2, got rc=$rc" >&2
  echo "$json_out" >&2
  exit 1
fi

JSON_OUT="$json_out" python3 - <<'PY'
import json, os
obj = json.loads(os.environ["JSON_OUT"])
assert obj["plugin_contract_version"] == 1
assert obj["ok"] is False
assert any("cli_version 0.3.3 < min_cli_version 9.9.9" in issue for issue in obj.get("issues", []))
PY

echo "plugin verify installed version ok"
