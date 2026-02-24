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
printf '%s' "$out" | python3 "$ROOT_DIR/tools/json_schema_validate.py" "$ROOT_DIR/docs/schemas/self_check.json"

echo "self-check json schema ok"
