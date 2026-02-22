#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

cfg="$(mktemp -d)"
trap 'rm -rf "$cfg"' EXIT

cat > "$cfg/linux-maint.conf" <<'EOF'
LM_OK=1
BAD LINE
LM_OK=2
EOF

out="$(LM_CFG_DIR="$cfg" bash "$LM" config --lint 2>&1 || true)"
printf '%s\n' "$out" | grep -q 'invalid lines:' || {
  echo "config --lint missing invalid lines section" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q 'duplicate keys:' || {
  echo "config --lint missing duplicate keys section" >&2
  echo "$out" >&2
  exit 1
}

echo "config lint ok"
