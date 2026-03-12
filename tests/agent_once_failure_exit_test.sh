#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REAL_LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

fake_lm="$workdir/linux-maint"
mkdir -p "$workdir/bin"
ln -s "$ROOT_DIR/monitors" "$workdir/monitors"
mkdir -p "$workdir/lib"
ln -s "$ROOT_DIR/lib/linux_maint.sh" "$workdir/lib/linux_maint.sh"
for support_lib in linux_maint_runtime.sh linux_maint_admin.sh linux_maint_help.sh linux_maint_tui.sh linux_maint_reporting.sh linux_maint_history.sh linux_maint_ops.sh; do
  ln -s "$ROOT_DIR/lib/$support_lib" "$workdir/lib/$support_lib"
done
cp "$ROOT_DIR/lib/linux_maint_advanced.sh" "$workdir/lib/linux_maint_advanced.sh"
ln -s "$ROOT_DIR/run_full_health_monitor.sh" "$workdir/run_full_health_monitor.sh"
fake_lm="$workdir/bin/linux-maint"
cp "$REAL_LM" "$fake_lm"
python3 - "$workdir/lib/linux_maint_advanced.sh" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
old = '\n        "$0" run\n        run_rc=$?\n'
new = "\n        bash -lc 'exit 7'\n        run_rc=$?\n"
text = path.read_text(encoding="utf-8")
if old not in text:
    raise SystemExit("agent test patch target not found")
path.write_text(text.replace(old, new, 1), encoding="utf-8")
PY
chmod +x "$fake_lm"

set +e
bash "$fake_lm" agent --once >/dev/null 2>&1
rc=$?
set -e

if [[ "$rc" -ne 7 ]]; then
  echo "expected agent --once to preserve run rc=7, got rc=$rc" >&2
  exit 1
fi

echo "agent once failure exit ok"
