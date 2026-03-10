#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

policy_file="$workdir/policy_bad_overall.conf"
cat > "$policy_file" <<'EOF'
max_crit=0
max_warn=10
max_unknown=5
max_skip=100
require_overall=BROKEN
EOF

set +e
out="$(bash "$LM" policy lint "$policy_file" 2>&1)"
rc=$?
set -e

if [[ "$rc" -ne 2 ]]; then
  echo "expected policy lint invalid require_overall failure rc=2, got rc=$rc" >&2
  echo "$out" >&2
  exit 1
fi

printf '%s\n' "$out" | grep -q 'require_overall must be one of' || {
  echo "unexpected policy lint output for invalid require_overall" >&2
  echo "$out" >&2
  exit 1
}

echo "policy lint require_overall ok"
