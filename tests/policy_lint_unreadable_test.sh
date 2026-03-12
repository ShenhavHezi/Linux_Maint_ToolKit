#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
policy_file="$workdir/policy.conf"
trap 'chmod 644 "$policy_file" 2>/dev/null || true; rm -rf "$workdir"' EXIT

cat > "$policy_file" <<'EOF'
max_crit=0
max_warn=5
require_overall=OK
EOF
chmod 000 "$policy_file"

set +e
out="$(bash "$LM" policy lint "$policy_file" 2>&1)"
rc=$?
set -e

[[ "$rc" -eq 2 ]] || {
  echo "expected policy lint unreadable failure rc=2, got rc=$rc" >&2
  echo "$out" >&2
  exit 1
}

printf '%s\n' "$out" | grep -q 'policy file not readable' || {
  echo "unexpected policy lint unreadable output" >&2
  echo "$out" >&2
  exit 1
}

echo "policy lint unreadable ok"
