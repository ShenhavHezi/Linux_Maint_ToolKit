#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$ROOT_DIR/tests/testlib.sh"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

prefix="$workdir/prefix"
cfg="$workdir/etc_linux_maint"
logs="$workdir/logs"
state="$workdir/state"
lock="$workdir/lock"
mkdir -p "$prefix/bin" "$prefix/lib" "$cfg" "$logs" "$state" "$lock"

cp "$ROOT_DIR/bin/linux-maint" "$prefix/bin/linux-maint"
chmod +x "$prefix/bin/linux-maint"
testlib_copy_support_libs "$ROOT_DIR" "$prefix/lib"
printf '# library\n' > "$prefix/lib/linux_maint.sh"
printf '%s\n' localhost > "$cfg/servers.txt"
: > "$cfg/excluded.txt"
: > "$cfg/services.txt"

human_out="$(PREFIX="$prefix" LM_CFG_DIR="$cfg" LOG_DIR="$logs" LM_STATE_DIR="$state" LM_LOCKDIR="$lock" "$prefix/bin/linux-maint" doctor --compact 2>&1)"
printf '%s\n' "$human_out" | grep -q "^lib=$prefix/lib/linux_maint.sh$" || {
  echo "installed doctor did not autodetect the installed library path" >&2
  echo "$human_out" >&2
  exit 1
}

json_out="$(PREFIX="$prefix" LM_CFG_DIR="$cfg" LOG_DIR="$logs" LM_STATE_DIR="$state" LM_LOCKDIR="$lock" "$prefix/bin/linux-maint" doctor --json)"
JSON_OUT="$json_out" EXPECTED_LIB="$prefix/lib/linux_maint.sh" python3 - <<'PY'
import json
import os

payload = json.loads(os.environ["JSON_OUT"])
assert payload["lib"] == os.environ["EXPECTED_LIB"], payload
PY

echo "doctor installed lib autodetect ok"
