#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

cfg="$workdir/etc_linux_maint"
mkdir -p "$cfg"

cat > "$cfg/linux-maint.conf" <<'EOF'
# LM_DARK_SITE=false
LM_DARK_SITE=false
EOF

LM_CFG_DIR="$cfg" LOG_DIR="$workdir/logs" bash "$LM" tune dark-site >/dev/null

active_count="$(grep -Ec '^LM_DARK_SITE=' "$cfg/linux-maint.conf")"
commented_count="$(grep -Ec '^# LM_DARK_SITE=' "$cfg/linux-maint.conf")"

[[ "$active_count" -eq 1 ]] || {
  echo "tune dark-site should not create duplicate active LM_DARK_SITE keys" >&2
  cat "$cfg/linux-maint.conf" >&2
  exit 1
}

[[ "$commented_count" -eq 1 ]] || {
  echo "tune dark-site should preserve existing commented LM_DARK_SITE when an active value exists" >&2
  cat "$cfg/linux-maint.conf" >&2
  exit 1
}

grep -q '^LM_DARK_SITE=false$' "$cfg/linux-maint.conf" || {
  echo "tune dark-site should keep the existing active LM_DARK_SITE value" >&2
  cat "$cfg/linux-maint.conf" >&2
  exit 1
}

echo "tune dark-site duplicate key ok"
