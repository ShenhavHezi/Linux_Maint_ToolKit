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

fips_json="$(LM_CFG_DIR="$cfg_dir" LOG_DIR="$workdir/logs" LM_STATE_DIR="$workdir/state" LM_LOCKDIR="$workdir/lock" LM_SSH_KNOWN_HOSTS_MODE=strict LM_SSH_ALLOWLIST_STRICT=1 LM_FIPS_ENABLED=1 bash "$LM" security-profile --json --fips 2>/dev/null || true)"
python3 - <<'PY' "$fips_json"
import json
import sys

obj = json.loads(sys.argv[1])
checks = {item["check"]: item for item in obj["checks"]}
assert obj["fips_requested"] is True
assert obj["fips_enabled"] is True
assert checks["fips_mode_enabled"]["ok"] is True
assert checks["fips_ssh_opts_no_weak_crypto"]["ok"] is True
print("security-profile fips json ok")
PY

set +e
LM_CFG_DIR="$cfg_dir" LOG_DIR="$workdir/logs" LM_STATE_DIR="$workdir/state" LM_LOCKDIR="$workdir/lock" LM_SSH_KNOWN_HOSTS_MODE=accept-new LM_SSH_ALLOWLIST_STRICT=0 bash "$LM" security-profile --strict >/dev/null 2>&1
rc=$?
set -e
[[ "$rc" -eq 2 ]] || {
  echo "expected strict security-profile failure rc=2, got rc=$rc" >&2
  exit 1
}

set +e
LM_CFG_DIR="$cfg_dir" LOG_DIR="$workdir/logs" LM_STATE_DIR="$workdir/state" LM_LOCKDIR="$workdir/lock" LM_SSH_KNOWN_HOSTS_MODE=strict LM_SSH_ALLOWLIST_STRICT=1 LM_FIPS_ENABLED=0 bash "$LM" security-profile --fips --strict >/dev/null 2>&1
rc=$?
set -e
[[ "$rc" -eq 2 ]] || {
  echo "expected strict FIPS security-profile failure rc=2, got rc=$rc" >&2
  exit 1
}

set +e
weak_out="$(LM_CFG_DIR="$cfg_dir" LOG_DIR="$workdir/logs" LM_STATE_DIR="$workdir/state" LM_LOCKDIR="$workdir/lock" LM_SSH_KNOWN_HOSTS_MODE=strict LM_SSH_ALLOWLIST_STRICT=1 LM_FIPS_ENABLED=1 LM_SSH_OPTS='-o Ciphers=3des-cbc' bash "$LM" security-profile --fips --strict 2>&1)"
rc=$?
set -e
[[ "$rc" -eq 2 ]] || {
  echo "expected strict FIPS weak-crypto failure rc=2, got rc=$rc" >&2
  echo "$weak_out" >&2
  exit 1
}
printf '%s\n' "$weak_out" | grep -q 'fips_ssh_opts_no_weak_crypto' || {
  echo "missing FIPS weak-crypto check output" >&2
  echo "$weak_out" >&2
  exit 1
}

echo "security profile command ok"
