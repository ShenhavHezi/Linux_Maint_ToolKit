#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

cfg="$workdir/etc_linux_maint"
mkdir -p "$cfg"
printf '%s\n' localhost > "$cfg/servers.txt"
: > "$cfg/excluded.txt"
: > "$cfg/services.txt"

out="$(LM_CFG_DIR="$cfg" LM_STATE_DIR="$workdir/state" LM_LOCKDIR="$workdir/lock" LOG_DIR="$workdir/logs" "$LM" self-check --json)"
python3 - <<'PY' "$out"
import json,sys
o=json.loads(sys.argv[1])
assert "mode" in o
assert "cfg_dir" in o
assert "config" in o and "files" in o["config"]
assert "paths" in o and isinstance(o["paths"], list)
assert "dependencies" in o and isinstance(o["dependencies"], list)
print("self-check json ok")
PY
