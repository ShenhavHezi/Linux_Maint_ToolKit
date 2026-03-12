#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REAL_LM="$ROOT_DIR/bin/linux-maint"
. "$ROOT_DIR/tests/testlib.sh"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

fake_lm="$workdir/linux-maint"
mkdir -p "$workdir/lib"
testlib_link_support_libs "$ROOT_DIR" "$workdir/lib" linux_maint_advanced.sh
cp "$ROOT_DIR/lib/linux_maint_advanced.sh" "$workdir/lib/linux_maint_advanced.sh"
cp "$REAL_LM" "$fake_lm"
python3 - "$workdir/lib/linux_maint_advanced.sh" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
old = 'st_json="$(NO_COLOR=1 "$0" status --json --reasons 8 --problems 12 2>/dev/null)"'
new = 'st_json="$(printf \'%s\\n\' \'{not-json\')"\n    st_rc=0'
text = path.read_text(encoding="utf-8")
if old not in text:
    raise SystemExit("ai-assist test patch target not found")
path.write_text(text.replace(old, new, 1), encoding="utf-8")
PY
chmod +x "$fake_lm"

set +e
out="$(bash "$fake_lm" ai-assist --json 2>&1)"
rc=$?
set -e

if [[ "$rc" -ne 2 ]]; then
  echo "expected ai-assist invalid status failure rc=2, got rc=$rc" >&2
  echo "$out" >&2
  exit 1
fi

printf '%s\n' "$out" | grep -q '^ERROR: ai-assist requires valid JSON from status --json$' || {
  echo "unexpected ai-assist invalid status output" >&2
  echo "$out" >&2
  exit 1
}

echo "ai-assist invalid status ok"
