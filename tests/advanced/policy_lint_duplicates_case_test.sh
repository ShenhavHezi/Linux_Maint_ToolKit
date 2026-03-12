#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

lowercase_policy="$workdir/policy_lowercase.conf"
cat > "$lowercase_policy" <<'EOF'
max_crit=0
max_warn=10
max_unknown=5
max_skip=100
require_overall=ok
EOF

bash "$LM" policy lint "$lowercase_policy" >/dev/null

dup_policy="$workdir/policy_duplicate.conf"
cat > "$dup_policy" <<'EOF'
max_crit=0
max_warn=10
max_warn=20
max_unknown=5
max_skip=100
require_overall=
EOF

set +e
out="$(bash "$LM" policy lint "$dup_policy" 2>&1)"
rc=$?
set -e

if [[ "$rc" -ne 2 ]]; then
  echo "expected policy lint duplicate key failure rc=2, got rc=$rc" >&2
  echo "$out" >&2
  exit 1
fi

printf '%s\n' "$out" | grep -q 'duplicate key max_warn' || {
  echo "unexpected policy lint duplicate key output" >&2
  echo "$out" >&2
  exit 1
}

echo "policy lint duplicates and case ok"
