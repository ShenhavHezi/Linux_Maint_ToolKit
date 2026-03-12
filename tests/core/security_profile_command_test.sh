#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT
cfg_dir="$workdir/etc"
mkdir -p "$cfg_dir" "$workdir/logs" "$workdir/state" "$workdir/lock"
chmod 0755 "$cfg_dir" "$workdir/logs" "$workdir/state" "$workdir/lock"

json_out="$(LM_CFG_DIR="$cfg_dir" LOG_DIR="$workdir/logs" LM_STATE_DIR="$workdir/state" LM_LOCKDIR="$workdir/lock" LM_SSH_KNOWN_HOSTS_MODE=strict LM_SSH_ALLOWLIST_STRICT=1 bash "$LM" security-profile --json 2>/dev/null || true)"
python3 - <<'PY' "$json_out"
import json
import sys

obj = json.loads(sys.argv[1])
assert obj["schema_version"] == 1
assert obj["security_profile_contract_version"] == 1
assert isinstance(obj["checks"], list) and len(obj["checks"]) >= 1
print("security-profile json ok")
PY

set +e
LM_CFG_DIR="$cfg_dir" LOG_DIR="$workdir/logs" LM_STATE_DIR="$workdir/state" LM_LOCKDIR="$workdir/lock" LM_SSH_KNOWN_HOSTS_MODE=accept-new LM_SSH_ALLOWLIST_STRICT=0 bash "$LM" security-profile --strict >/dev/null 2>&1
rc=$?
set -e
[[ "$rc" -eq 2 ]] || {
  echo "expected strict security-profile failure rc=2, got rc=$rc" >&2
  exit 1
}

echo "security profile command ok"
