#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

policy_file="$workdir/bad-policy.conf"
cat > "$policy_file" <<'EOF'
max_crit=0
max_warn=oops
require_overall=BROKEN
EOF

set +e
out="$(bash "$LM" gate --policy "$policy_file" --json 2>&1)"
rc=$?
set -e

[[ "$rc" -eq 2 ]] || {
  echo "expected gate invalid policy failure rc=2, got rc=$rc" >&2
  echo "$out" >&2
  exit 1
}

printf '%s\n' "$out" | grep -q 'gate requires a valid policy file' || {
  echo "unexpected gate invalid policy output" >&2
  echo "$out" >&2
  exit 1
}

printf '%s\n' "$out" | grep -q 'max_warn must be integer' || {
  echo "gate output did not include invalid integer detail" >&2
  echo "$out" >&2
  exit 1
}

echo "gate invalid policy file ok"
