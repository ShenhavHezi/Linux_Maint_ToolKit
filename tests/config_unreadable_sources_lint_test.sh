#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

cfg="$(mktemp -d)"
trap 'chmod 600 "$cfg/linux-maint.conf" 2>/dev/null || true; rm -rf "$cfg"' EXIT

printf 'LM_NOTIFY=1\n' > "$cfg/linux-maint.conf"
chmod 000 "$cfg/linux-maint.conf"

set +e
out="$(LM_CFG_DIR="$cfg" bash "$LM" config --lint 2>&1)"
rc=$?
set -e

if [[ "$rc" -ne 1 ]]; then
  echo "expected config --lint unreadable source rc=1, got rc=$rc" >&2
  echo "$out" >&2
  exit 1
fi

printf '%s\n' "$out" | grep -q '^ERROR: Cannot read config file(s)$' || {
  echo "config --lint unreadable source missing error header" >&2
  echo "$out" >&2
  exit 1
}

printf '%s\n' "$out" | grep -q '/linux-maint\.conf$' || {
  echo "config --lint unreadable source missing file path" >&2
  echo "$out" >&2
  exit 1
}

printf '%s\n' "$out" | grep -q 'Traceback' && {
  echo "config --lint unreadable source should not crash" >&2
  echo "$out" >&2
  exit 1
}

echo "config unreadable sources lint ok"
