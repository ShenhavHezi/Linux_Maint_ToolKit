#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

policy_file="$workdir/policy.conf"
bash "$LM" policy init "$policy_file" >/dev/null
[[ -f "$policy_file" ]] || {
  echo "policy init did not create file" >&2
  exit 1
}
grep -q '^max_crit=' "$policy_file" || {
  echo "policy template missing max_crit key" >&2
  exit 1
}

bash "$LM" policy lint "$policy_file" >/dev/null

bad_policy="$workdir/policy_bad.conf"
cat > "$bad_policy" <<'P'
max_crit=foo
unknown_key=1
P
set +e
bash "$LM" policy lint "$bad_policy" >/dev/null 2>&1
rc=$?
set -e
[[ "$rc" -eq 2 ]] || {
  echo "expected policy lint failure rc=2, got rc=$rc" >&2
  exit 1
}

pass_policy="$workdir/policy_pass.conf"
cat > "$pass_policy" <<'P'
max_crit=999999
max_warn=999999
max_unknown=999999
max_skip=999999
require_overall=
P
bash "$LM" policy eval --policy "$pass_policy" >/dev/null

echo "policy command ok"
