#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

cfg="$workdir/etc_linux_maint"
logdir="$workdir/logs"
statedir="$workdir/state"
lockdir="$workdir/lock"
inventorydir="$workdir/inventory"
mkdir -p "$cfg" "$logdir" "$statedir" "$lockdir" "$inventorydir"

printf '%s\n' localhost > "$cfg/servers.txt"
: > "$cfg/excluded.txt"
: > "$cfg/services.txt"

before="$(
  python3 - <<'PY' "$logdir" "$statedir" "$lockdir" "$inventorydir"
import os
import sys

for path in sys.argv[1:]:
    print(f"{path}\t{os.stat(path).st_mtime_ns}")
PY
)"

LM_CFG_DIR="$cfg" LOG_DIR="$logdir" LM_STATE_DIR="$statedir" LM_LOCKDIR="$lockdir" LM_INVENTORY_OUTPUT_DIR="$inventorydir" "$LM" doctor --json >/dev/null
LM_CFG_DIR="$cfg" LOG_DIR="$logdir" LM_STATE_DIR="$statedir" LM_LOCKDIR="$lockdir" "$LM" verify-install >/dev/null

after="$(
  python3 - <<'PY' "$logdir" "$statedir" "$lockdir" "$inventorydir"
import os
import sys

for path in sys.argv[1:]:
    print(f"{path}\t{os.stat(path).st_mtime_ns}")
PY
)"

[[ "$before" == "$after" ]] || {
  echo "doctor/verify-install changed directory mtimes" >&2
  printf 'before:\n%s\nafter:\n%s\n' "$before" "$after" >&2
  exit 1
}

for probe in \
  "$logdir/.lm_write_test" \
  "$statedir/.lm_write_test" \
  "$lockdir/.lm_write_test" \
  "$inventorydir/.lm_write_test" \
  "$logdir/.linux_maint_write_test" \
  "$statedir/.linux_maint_write_test" \
  "$lockdir/.linux_maint_write_test" \
  "$inventorydir/.linux_maint_write_test"
do
  [[ ! -e "$probe" ]] || {
    echo "unexpected probe file left behind: $probe" >&2
    exit 1
  }
done

echo "doctor/verify-install no side effects ok"
