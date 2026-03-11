#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

cfg="$(mktemp -d)"
trap 'rm -rf "$cfg"' EXIT

cat > "$cfg/linux-maint.conf" <<'EOF'
LM_NOTIFY=0
LM_NOTIFY=1
EOF

set +e
out="$(LM_CFG_DIR="$cfg" bash "$LM" config --lint 2>&1)"
rc=$?
set -e

[[ "$rc" -eq 1 ]] || {
  echo "config --lint should exit 1 for duplicate keys, got rc=$rc" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q 'duplicate keys:' || {
  echo "config --lint missing duplicate keys section" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q 'LM_NOTIFY' || {
  echo "config --lint missing duplicate key name" >&2
  echo "$out" >&2
  exit 1
}

echo "config lint duplicates exit ok"
