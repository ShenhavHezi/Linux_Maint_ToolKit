#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

cfg="$workdir/etc_linux_maint"
mkdir -p "$cfg" "$workdir/logs" "$workdir/state" "$workdir/lock"
printf '%s\n' localhost > "$cfg/servers.txt"
: > "$cfg/excluded.txt"
# services.txt intentionally missing so strict self-check should fail

set +e
out="$(LM_CFG_DIR="$cfg" LOG_DIR="$workdir/logs" LM_STATE_DIR="$workdir/state" LM_LOCKDIR="$workdir/lock" "$LM" self-check --json --strict 2>/dev/null)"
rc=$?
set -e

[[ "$rc" -eq 2 ]] || {
  echo "expected self-check --json --strict rc=2, got rc=$rc" >&2
  echo "$out" >&2
  exit 1
}

SELF_JSON="$out" python3 - <<'PY'
import json, os
obj = json.loads(os.environ["SELF_JSON"])
assert obj["schema_version"] == 1
assert obj["self_check_json_contract_version"] == 1
assert obj["strict"] is True
assert obj["ok"] is False
print("self-check json strict exit ok")
PY
