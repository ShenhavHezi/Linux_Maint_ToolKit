#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'chmod 600 "$workdir/cfg/servers.txt" 2>/dev/null || true; rm -rf "$workdir"' EXIT

cfg="$workdir/cfg"
logs="$workdir/logs"
state="$workdir/state"
lock="$workdir/lock"
mkdir -p "$cfg" "$logs" "$state" "$lock"
printf '%s\n' localhost > "$cfg/servers.txt"
: > "$cfg/excluded.txt"
: > "$cfg/services.txt"
if [[ "$(id -u)" -eq 0 ]]; then
  if ! command -v su >/dev/null 2>&1 || ! getent passwd nobody >/dev/null 2>&1; then
    echo "doctor json unreadable servers skipped under root: no su/nobody"
    exit 0
  fi
  if ! su -s /bin/bash nobody -c "test -r '$LM'" >/dev/null 2>&1; then
    echo "doctor json unreadable servers skipped under root: repo path not readable by nobody"
    exit 0
  fi
  chmod 755 "$cfg" "$logs" "$state" "$lock"
  chmod 777 "$logs" "$state" "$lock"
  chmod 600 "$cfg/servers.txt"
  set +e
  out="$(su -s /bin/bash nobody -c "LM_CFG_DIR='$cfg' LOG_DIR='$logs' LM_STATE_DIR='$state' LM_LOCKDIR='$lock' bash '$LM' doctor --json" 2>&1)"
  rc=$?
  set -e
else
  chmod 000 "$cfg/servers.txt"
  set +e
  out="$(LM_CFG_DIR="$cfg" LOG_DIR="$logs" LM_STATE_DIR="$state" LM_LOCKDIR="$lock" bash "$LM" doctor --json 2>&1)"
  rc=$?
  set -e
fi

if [[ "$rc" -ne 0 ]]; then
  echo "expected doctor --json to survive unreadable servers.txt, got rc=$rc" >&2
  echo "$out" >&2
  exit 1
fi

printf '%s' "$out" | python3 "$ROOT_DIR/tools/json_schema_validate.py" "$ROOT_DIR/docs/schemas/doctor.json"
OUT_JSON="$out" python3 - <<'PY'
import json, os
obj = json.loads(os.environ["OUT_JSON"])
cfg = obj["config"]
assert cfg["hosts_configured"] == 0
assert cfg["servers_readable"] is False
assert cfg["servers_error"] == "permission_denied"
assert any("servers.txt is readable" in item for item in obj["fix_suggestions"]), obj["fix_suggestions"]
assert obj["ok"] is True
PY

echo "doctor json unreadable servers ok"
