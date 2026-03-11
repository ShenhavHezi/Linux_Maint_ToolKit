#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REAL_LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

mkdir -p "$workdir/bin"
ln -s "$ROOT_DIR/monitors" "$workdir/monitors"
mkdir -p "$workdir/lib"
ln -s "$ROOT_DIR/lib/linux_maint.sh" "$workdir/lib/linux_maint.sh"
for support_lib in linux_maint_runtime.sh linux_maint_admin.sh linux_maint_help.sh linux_maint_tui.sh linux_maint_advanced.sh; do
  ln -s "$ROOT_DIR/lib/$support_lib" "$workdir/lib/$support_lib"
done
cp "$ROOT_DIR/lib/linux_maint_reporting.sh" "$workdir/lib/linux_maint_reporting.sh"
ln -s "$ROOT_DIR/run_full_health_monitor.sh" "$workdir/run_full_health_monitor.sh"
fake_lm="$workdir/bin/linux-maint"
cp "$REAL_LM" "$fake_lm"
python3 - "$workdir/lib/linux_maint_reporting.sh" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
old = '"$0" status --json --problems 20 --reasons 10 >"$tmp_status" 2>/dev/null || status_rc=$?'
new = 'printf \'%s\\n\' \'{not-json\' >"$tmp_status"\n    status_rc=0'
text = path.read_text(encoding="utf-8")
if old not in text:
    raise SystemExit("report test patch target not found")
path.write_text(text.replace(old, new, 1), encoding="utf-8")
PY
chmod +x "$fake_lm"

set +e
out="$(bash "$fake_lm" report --json 2>&1)"
rc=$?
set -e

if [[ "$rc" -ne 2 ]]; then
  echo "expected report invalid status rc=2, got rc=$rc" >&2
  echo "$out" >&2
  exit 1
fi

printf '%s\n' "$out" | grep -q '^ERROR: report requires valid JSON from status --json$' || {
  echo "unexpected report invalid status output" >&2
  echo "$out" >&2
  exit 1
}

echo "report invalid status ok"
