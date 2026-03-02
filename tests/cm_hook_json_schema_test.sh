#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"
TMPDIR="${TMPDIR:-/tmp}"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT
audit_file="$workdir/audit.log"

json_out="$(LM_AUDIT_LOG="$audit_file" bash "$LM" cm-hook --provider ansible --target web1 --module ping --dry-run --json)"
printf '%s' "$json_out" | python3 "$ROOT_DIR/tools/json_schema_validate.py" "$ROOT_DIR/docs/schemas/cm_hook.json"

echo "cm-hook json schema ok"
