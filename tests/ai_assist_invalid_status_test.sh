#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REAL_LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

fake_lm="$workdir/linux-maint"
mkdir -p "$workdir/lib"
for support_lib in linux_maint_runtime.sh linux_maint_admin.sh linux_maint_help.sh linux_maint_tui.sh linux_maint_reporting.sh; do
  ln -s "$ROOT_DIR/lib/$support_lib" "$workdir/lib/$support_lib"
done
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
