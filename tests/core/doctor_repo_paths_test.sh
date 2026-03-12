#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
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
: > "$cfg/emails.txt"

out="$(
  LM_CFG_DIR="$cfg" \
  LOG_DIR="$logdir" \
  LM_STATE_DIR="$statedir" \
  LM_LOCKDIR="$lockdir" \
  LM_INVENTORY_OUTPUT_DIR="$inventorydir" \
  "$LM" doctor --json
)"

python3 - <<'PY' "$out" "$logdir" "$statedir" "$lockdir" "$inventorydir"
import json
import sys

obj = json.loads(sys.argv[1])
logdir, statedir, lockdir, inventorydir = sys.argv[2:6]

paths = {row["path"] for row in obj["writable_locations"]}
expected = {logdir, statedir, lockdir, inventorydir}
assert expected.issubset(paths), paths
assert "/var/log/health" not in paths, paths
assert "/var/lib/linux_maint" not in paths, paths
assert "/var/lock" not in paths, paths

next_actions = obj["next_actions"]
assert all(not action.startswith("sudo ") for action in next_actions), next_actions
assert "linux-maint init" in next_actions, next_actions
assert "linux-maint preflight" in next_actions, next_actions
assert "linux-maint run" in next_actions, next_actions
PY

echo "doctor repo paths ok"
