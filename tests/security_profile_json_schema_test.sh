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
: > "$cfg/services.txt"

out="$(LM_CFG_DIR="$cfg" LM_STATE_DIR="$workdir/state" LM_LOCKDIR="$workdir/lock" LOG_DIR="$workdir/logs" LM_SSH_KNOWN_HOSTS_MODE=strict LM_SSH_ALLOWLIST_STRICT=1 "$LM" security-profile --json)"
printf '%s' "$out" | python3 "$ROOT_DIR/tools/json_schema_validate.py" "$ROOT_DIR/docs/schemas/security_profile.json"

echo "security-profile json schema ok"
