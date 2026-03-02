#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

json_out="$(bash "$LM" ticket --provider jira --url https://example.invalid/jira --title "Title" --body "Body" --dry-run --json)"
printf '%s' "$json_out" | python3 "$ROOT_DIR/tools/json_schema_validate.py" "$ROOT_DIR/docs/schemas/ticket.json"

echo "ticket json schema ok"
