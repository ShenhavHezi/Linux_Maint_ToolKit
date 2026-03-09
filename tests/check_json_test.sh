#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

out="$(bash "$LM" check --json 2>&1)"

printf '%s' "$out" | python3 -c 'import json,sys; data=json.load(sys.stdin); \
    assert data["schema_version"] == 1; \
    assert data["check_json_contract_version"] == 1; \
    [data[k] for k in ("config_validate","preflight","expected_skips","ok")]; \
    print("check json ok")'
