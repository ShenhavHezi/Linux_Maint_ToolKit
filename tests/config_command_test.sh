#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

cfg="$(mktemp -d)"
trap 'rm -rf "$cfg"' EXIT

cat > "$cfg/linux-maint.conf" <<'EOF'
LM_FOO=bar
LM_NUM=123
EOF

out="$(LM_CFG_DIR="$cfg" bash "$LM" config 2>&1 || true)"
printf '%s\n' "$out" | grep -q '^=== linux-maint config' || {
  echo "config header missing" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q '^LM_FOO[[:space:]]' || {
  echo "config missing LM_FOO" >&2
  echo "$out" >&2
  exit 1
}

json_out="$(LM_CFG_DIR="$cfg" bash "$LM" config --json 2>/dev/null || true)"
JSON_OUT="$json_out" python3 - <<'PY'
import json, os
data = json.loads(os.environ.get("JSON_OUT", ""))
assert data.get("values", {}).get("LM_FOO") == "bar"
assert data.get("values", {}).get("LM_NUM") == "123"
PY

echo "config command ok"
