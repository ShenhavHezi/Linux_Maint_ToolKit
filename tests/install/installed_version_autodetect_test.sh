#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$ROOT_DIR/tests/testlib.sh"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

prefix="$workdir/prefix"
mkdir -p "$prefix/bin" "$prefix/lib" "$prefix/share/linux_maint"

cp "$ROOT_DIR/bin/linux-maint" "$prefix/bin/linux-maint"
chmod +x "$prefix/bin/linux-maint"
testlib_copy_support_libs "$ROOT_DIR" "$prefix/lib"
cat > "$prefix/share/linux_maint/BUILD_INFO" <<'EOF'
project=Linux_Maint_ToolKit
version=v9.9.9
commit=testdeadbeef
branch=main
built_at_utc=2026-03-10T00:00:00Z
EOF

out="$("$prefix/bin/linux-maint" version)"
printf '%s\n' "$out" | grep -q '^version=v9.9.9$' || {
  echo "installed linux-maint did not autodetect prefix for BUILD_INFO" >&2
  echo "$out" >&2
  exit 1
}

short_out="$("$prefix/bin/linux-maint" version --short)"
printf '%s\n' "$short_out" | grep -q '^linux-maint v9.9.9 (commit testdeadbeef, built unknown)$' || {
  echo "installed linux-maint version --short did not emit expected summary" >&2
  echo "$short_out" >&2
  exit 1
}

json_out="$("$prefix/bin/linux-maint" version --json)"
python3 - <<'PY' "$json_out"
import json
import sys

payload = json.loads(sys.argv[1])
assert payload["version_json_contract_version"] == 1, payload
assert payload["version"] == "v9.9.9", payload
assert payload["commit"] == "testdeadbeef", payload
assert payload["build_info_file"].endswith("/share/linux_maint/BUILD_INFO"), payload
PY

echo "installed version autodetect ok"
