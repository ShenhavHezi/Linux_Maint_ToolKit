#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

cfg="$workdir/etc_linux_maint"
mkdir -p "$cfg"

cat > "$cfg/linux-maint.conf" <<'EOF'
LM_MAX_PARALLEL=foo
LM_NOTIFY=maybe
LM_PREFLIGHT_OPT_CMDS="openssl, bad cmd"
EOF

out="$(LM_CFG_DIR="$cfg" bash "$LM" config --json 2>&1 || true)"
printf '%s' "$out" | python3 -c 'import json,sys; o=json.load(sys.stdin); assert o.get("error")=="invalid_types"; keys={e.get("key") for e in o.get("errors",[])}; assert "LM_MAX_PARALLEL" in keys; assert "LM_NOTIFY" in keys; assert "LM_PREFLIGHT_OPT_CMDS" in keys; print("config type validation ok")'
