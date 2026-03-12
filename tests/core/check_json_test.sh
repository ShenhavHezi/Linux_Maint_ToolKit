#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"
workdir="$(mktemp -d -p "${TMPDIR:-/tmp}")"
trap 'rm -rf "$workdir"' EXIT

cfg="$workdir/etc_linux_maint"
mkdir -p "$cfg" "$workdir/state" "$workdir/lock" "$workdir/logs"
printf '%s\n' localhost > "$cfg/servers.txt"
printf '%s\n' localhost > "$cfg/excluded.txt"
printf '%s\n' sshd > "$cfg/services.txt"

set +e
out="$(LM_CFG_DIR="$cfg" LM_STATE_DIR="$workdir/state" LM_LOCKDIR="$workdir/lock" LOG_DIR="$workdir/logs" LM_PREFLIGHT_OPT_CMDS='awk sed grep df ssh' bash "$LM" check --json 2>&1)"
rc=$?
set -e

[[ "$rc" -eq 1 ]] || {
    echo "expected check --json rc=1 for warn-only input, got rc=$rc" >&2
    echo "$out" >&2
    exit 1
}

printf '%s' "$out" | python3 -c 'import json,sys; data=json.load(sys.stdin); \
    assert data["schema_version"] == 1; \
    assert data["check_json_contract_version"] == 1; \
    [data[k] for k in ("config_validate","preflight","expected_skips","ok")]; \
    print("check json ok")'
