#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"
TMPDIR="${TMPDIR:-/tmp}"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT
audit_file="$workdir/audit.log"

set +e
bash "$LM" cm-hook --provider unknown --dry-run >/dev/null 2>&1
rc_bad=$?
set -e
[[ "$rc_bad" -eq 2 ]] || {
  echo "expected invalid provider rc=2, got rc=$rc_bad" >&2
  exit 1
}

out1="$(LM_AUDIT_LOG="$audit_file" bash "$LM" cm-hook --provider ansible --target web1,web2 --module ping --dry-run 2>/dev/null || true)"
printf '%s\n' "$out1" | grep -q '^DRY_RUN provider=ansible cmd=' || {
  echo "expected ansible dry-run output" >&2
  echo "$out1" >&2
  exit 1
}

out2="$(LM_AUDIT_LOG="$audit_file" bash "$LM" cm-hook --provider puppet --dry-run 2>/dev/null || true)"
printf '%s\n' "$out2" | grep -q '^DRY_RUN provider=puppet cmd=' || {
  echo "expected puppet dry-run output" >&2
  echo "$out2" >&2
  exit 1
}

out3="$(LM_AUDIT_LOG="$audit_file" bash "$LM" cm-hook --provider salt --target minion1 --args test.ping --dry-run 2>/dev/null || true)"
printf '%s\n' "$out3" | grep -q '^DRY_RUN provider=salt cmd=' || {
  echo "expected salt dry-run output" >&2
  echo "$out3" >&2
  exit 1
}

json_out_cm="$(LM_AUDIT_LOG="$audit_file" bash "$LM" cm-hook --provider ansible --target web1 --module ping --dry-run --json 2>/dev/null || true)"
JSON_OUT="$json_out_cm" python3 - <<'PY'
import json, os
o = json.loads(os.environ["JSON_OUT"])
assert o["cm_hook_contract_version"] == 1
assert o["provider"] == "ansible"
assert o["dry_run"] is True
assert o["executed"] is False
assert o["rc"] == 0
assert isinstance(o.get("cmd"), str) and o["cmd"]
PY

json_out="$(LM_AUDIT_LOG="$audit_file" bash "$LM" audit-log --json --last 20 2>/dev/null || true)"
JSON_OUT="$json_out" python3 - <<'PY'
import json, os
o = json.loads(os.environ["JSON_OUT"])
actions = [e.get("action") for e in (o.get("events") or []) if isinstance(e, dict)]
assert "cm-hook" in actions
PY

echo "cm-hook command ok"
