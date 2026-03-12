#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REAL_LM="$ROOT_DIR/bin/linux-maint"
. "$ROOT_DIR/tests/testlib.sh"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

policy_file="$workdir/policy.conf"
cat > "$policy_file" <<'P'
max_crit=999999
max_warn=999999
max_unknown=999999
max_skip=999999
require_overall=
P

fake_lm="$workdir/linux-maint"
mkdir -p "$workdir/lib"
testlib_link_support_libs "$ROOT_DIR" "$workdir/lib" linux_maint_advanced.sh
cp "$ROOT_DIR/lib/linux_maint_advanced.sh" "$workdir/lib/linux_maint_advanced.sh"
cp "$REAL_LM" "$fake_lm"
python3 - "$workdir/lib/linux_maint_advanced.sh" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
old = 'status_json="$(NO_COLOR=1 "$0" status --json 2>/dev/null)"'
new = 'status_json="$(printf \'%s\\n\' \'{\"status_json_contract_version\":1,\"last_status\":{\"overall\":\"OK\"},\"totals\":{\"CRIT\":\"oops\",\"WARN\":0,\"UNKNOWN\":0,\"SKIP\":0,\"OK\":1}}\')"\n    gate_status_rc=0'
text = path.read_text(encoding="utf-8")
if old not in text:
    raise SystemExit("gate shape test patch target not found")
path.write_text(text.replace(old, new, 1), encoding="utf-8")
PY
chmod +x "$fake_lm"

set +e
out="$(bash "$fake_lm" gate --policy "$policy_file" --json 2>&1)"
rc=$?
set -e

if [[ "$rc" -ne 2 ]]; then
  echo "expected gate invalid status shape failure rc=2, got rc=$rc" >&2
  echo "$out" >&2
  exit 1
fi

printf '%s\n' "$out" | grep -q '^ERROR: gate requires integer severity totals from status --json$' || {
  echo "unexpected gate invalid status shape output" >&2
  echo "$out" >&2
  exit 1
}

echo "gate invalid status shape ok"
