#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

out="$(bash "$LM" check --json 2>&1)"

printf '%s' "$out" | python3 -c 'import json,sys; data=json.load(sys.stdin); \
    [data[k] for k in ("config_validate","preflight","expected_skips","ok")]; \
    print("check json ok")'
