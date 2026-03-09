#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

cfg="$(mktemp -d)"
trap 'rm -rf "$cfg"' EXIT

cat > "$cfg/linux-maint.conf" <<'EOF'
LM_FOO=bar
exit 7
EOF

set +e
out="$(LM_CFG_DIR="$cfg" bash "$LM" config 2>&1)"
rc=$?
set -e

if [[ "$rc" -ne 1 ]]; then
  echo "expected config source failure rc=1, got rc=$rc" >&2
  echo "$out" >&2
  exit 1
fi

printf '%s\n' "$out" | grep -q "Hint: fix the config file and rerun 'linux-maint config'" || {
  echo "config source failure missing neutral hint" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q 'sudo linux-maint config' && {
  echo "config source failure leaked installed-mode sudo hint" >&2
  echo "$out" >&2
  exit 1
}

echo "config source failure human hint ok"
