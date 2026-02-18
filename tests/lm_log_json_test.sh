#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$ROOT_DIR/lib/linux_maint.sh"

logfile="$TMPDIR/lm_json.log"
: > "$logfile"
LM_LOG_FORMAT=json LM_LOGFILE="$logfile" bash -c ". \"$LIB\"; lm_info \"hello world\""

python3 - <<'PY' "$logfile"
import json,sys
obj=json.loads(open(sys.argv[1]).read().strip())
assert obj["level"] == "INFO"
assert obj["msg"] == "hello world"
print("lm_log json ok")
PY

grep -q '"level":"INFO"' "$logfile"
