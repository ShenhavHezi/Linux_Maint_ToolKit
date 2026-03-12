#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REAL_LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

fake_lm="$workdir/linux-maint"
mkdir -p "$workdir/lib"
for support_lib in linux_maint_runtime.sh linux_maint_admin.sh linux_maint_help.sh linux_maint_tui.sh linux_maint_reporting.sh linux_maint_history.sh linux_maint_ops.sh; do
  ln -s "$ROOT_DIR/lib/$support_lib" "$workdir/lib/$support_lib"
done
cp "$ROOT_DIR/lib/linux_maint_advanced.sh" "$workdir/lib/linux_maint_advanced.sh"
cp "$REAL_LM" "$fake_lm"
python3 - "$workdir/lib/linux_maint_advanced.sh" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
old = 'hist_json="$(NO_COLOR=1 "$0" history --json --last "$P_LAST" 2>/dev/null)"'
new = 'hist_json="$(printf \'%s\\n\' \'{not-json\')"\n    hist_rc=0'
text = path.read_text(encoding="utf-8")
if old not in text:
    raise SystemExit("predict test patch target not found")
path.write_text(text.replace(old, new, 1), encoding="utf-8")
PY
chmod +x "$fake_lm"

set +e
out="$(bash "$fake_lm" predict --last 5 --json 2>&1)"
rc=$?
set -e

if [[ "$rc" -ne 2 ]]; then
  echo "expected predict invalid history failure rc=2, got rc=$rc" >&2
  echo "$out" >&2
  exit 1
fi

printf '%s\n' "$out" | grep -q '^ERROR: predict requires valid JSON from history --json$' || {
  echo "unexpected predict invalid history output" >&2
  echo "$out" >&2
  exit 1
}

echo "predict invalid history ok"
