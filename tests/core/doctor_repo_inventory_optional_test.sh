#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

cfg="$workdir/cfg"
logs="$workdir/logs"
state="$workdir/state"
lock="$workdir/lock"
mkdir -p "$cfg" "$logs" "$state" "$lock"
printf '%s\n' localhost > "$cfg/servers.txt"
: > "$cfg/excluded.txt"
: > "$cfg/services.txt"
: > "$cfg/emails.txt"

out="$(
  LM_CFG_DIR="$cfg" \
  LOG_DIR="$logs" \
  LM_STATE_DIR="$state" \
  LM_LOCKDIR="$lock" \
  bash "$LM" doctor --json
)"

OUT_JSON="$out" python3 - <<'PY' "$logs" "$state" "$lock"
import json, os, sys
obj = json.loads(os.environ["OUT_JSON"])
logs, state, lock = sys.argv[1:4]
paths = {row["path"] for row in obj["writable_locations"]}
assert logs in paths
assert state in paths
assert lock in paths
assert "/var/log/inventory" not in paths, paths
assert all("/var/log/inventory" not in item for item in obj["fix_suggestions"]), obj["fix_suggestions"]
assert obj["ok"] is True
PY

echo "doctor repo inventory optional ok"
