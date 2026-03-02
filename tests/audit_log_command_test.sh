#!/usr/bin/env bash
set -euo pipefail

TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

audit_file="$workdir/audit.log"
plug_src="$workdir/sample-plugin"
plug_dir="$workdir/plugins"
mkdir -p "$plug_src"
cat > "$plug_src/plugin.json" <<'P'
{
  "name": "sample_plugin",
  "version": "0.1.0",
  "description": "sample plugin"
}
P

LM_AUDIT_LOG="$audit_file" LM_PLUGIN_DIR="$plug_dir" bash "$LM" plugin install "$plug_src" >/dev/null
LM_AUDIT_LOG="$audit_file" LM_PLUGIN_DIR="$plug_dir" bash "$LM" plugin remove sample_plugin >/dev/null

set +e
LM_AUDIT_LOG="$audit_file" bash "$LM" doctor --fix --dry-run --yes >/dev/null 2>&1
rc_fix=$?
set -e
[[ "$rc_fix" -eq 1 ]] || {
  echo "expected doctor --fix as non-root to fail rc=1, got rc=$rc_fix" >&2
  exit 1
}

json_out="$(LM_AUDIT_LOG="$audit_file" bash "$LM" audit-log --json --last 50 2>/dev/null || true)"
JSON_OUT="$json_out" python3 - <<'PY'
import json, os
o = json.loads(os.environ["JSON_OUT"])
assert o["audit_contract_version"] == 1
events = o.get("events") or []
assert len(events) >= 3
actions = [e.get("action") for e in events]
assert "plugin-install" in actions
assert "plugin-remove" in actions
assert "doctor-fix" in actions
for e in events:
    if "action" in e:
        assert "chain_hash" in e
PY

text_out="$(LM_AUDIT_LOG="$audit_file" bash "$LM" audit-log --last 5 2>/dev/null || true)"
printf '%s\n' "$text_out" | grep -q '^=== linux-maint audit-log ===' || {
  echo "audit-log text header missing" >&2
  echo "$text_out" >&2
  exit 1
}

LM_AUDIT_LOG="$audit_file" bash "$LM" audit-log --verify >/dev/null
verify_json="$(LM_AUDIT_LOG="$audit_file" bash "$LM" audit-log --verify --json 2>/dev/null || true)"
VERIFY_JSON="$verify_json" python3 - <<'PY'
import json, os
o = json.loads(os.environ["VERIFY_JSON"])
assert o["valid"] is True
assert int(o.get("events_checked", 0)) >= 3
PY

echo "audit log command ok"
