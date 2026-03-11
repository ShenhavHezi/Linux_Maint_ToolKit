#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'chmod 755 "$workdir/cfg" 2>/dev/null || true; rm -rf "$workdir"' EXIT

cfg="$workdir/cfg"
logs="$workdir/logs"
state="$workdir/state"
lock="$workdir/lock"
inv="$workdir/inventory"
mkdir -p "$cfg" "$logs" "$state" "$lock" "$inv"
printf '%s\n' localhost > "$cfg/servers.txt"
: > "$cfg/excluded.txt"
: > "$cfg/services.txt"
: > "$cfg/emails.txt"
chmod 777 "$cfg"

set +e
out="$(LM_CFG_DIR="$cfg" LOG_DIR="$logs" LM_STATE_DIR="$state" LM_LOCKDIR="$lock" LM_INVENTORY_OUTPUT_DIR="$inv" LM_STRICT=1 bash "$LM" doctor --json 2>&1)"
rc=$?
set -e

if [[ "$rc" -ne 2 ]]; then
  echo "expected doctor --json strict rc=2 on CRIT permissions, got rc=$rc" >&2
  echo "$out" >&2
  exit 1
fi

printf '%s' "$out" | python3 "$ROOT_DIR/tools/json_schema_validate.py" "$ROOT_DIR/docs/schemas/doctor.json"
OUT_JSON="$out" python3 - <<'PY'
import json, os
obj = json.loads(os.environ["OUT_JSON"])
assert obj["strict"] is True
assert obj["ok"] is False
assert any(item["severity"] == "CRIT" for item in obj["dir_permissions"])
PY

echo "doctor json strict exit ok"
