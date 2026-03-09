#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

out="$(bash "$LM" check --json 2>&1)"

printf '%s' "$out" | python3 "$ROOT_DIR/tools/json_schema_validate.py" "$ROOT_DIR/docs/schemas/check.json"

echo "check json schema ok"
