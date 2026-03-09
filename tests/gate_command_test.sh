#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

ok_policy="$workdir/policy_ok.conf"
cat > "$ok_policy" <<'P'
max_crit=999999
max_warn=999999
max_unknown=999999
max_skip=999999
require_overall=
P

bash "$LM" gate --policy "$ok_policy" >/dev/null

bad_policy="$workdir/policy_bad.conf"
cat > "$bad_policy" <<'P'
max_crit=999999
max_warn=999999
max_unknown=999999
max_skip=999999
require_overall=__NEVER_MATCH__
P

set +e
bash "$LM" gate --policy "$bad_policy" >/dev/null 2>&1
rc=$?
set -e
[[ "$rc" -eq 2 ]] || {
  echo "expected gate fail rc=2, got rc=$rc" >&2
  exit 1
}

json_out="$(bash "$LM" gate --policy "$ok_policy" --json 2>/dev/null || true)"
printf '%s\n' "$json_out" | grep -q '"gate_contract_version"' || {
  echo "gate --json missing contract version" >&2
  echo "$json_out" >&2
  exit 1
}

echo "gate command ok"
