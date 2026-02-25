#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

out="$(bash "$LM" check --json 2>&1)"

python3 - <<'PY' <<<"$out"
import json, sys
text = sys.stdin.read()
try:
    data = json.loads(text)
except Exception as e:
    print("invalid json:", e, file=sys.stderr)
    print(text, file=sys.stderr)
    sys.exit(1)
for key in ("config_validate","preflight","expected_skips","ok"):
    if key not in data:
        print(f"missing key: {key}", file=sys.stderr)
        sys.exit(1)
print("check json ok")
PY
