#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

plug_src="$workdir/signed-plugin"
plug_dir="$workdir/plugins"
mkdir -p "$plug_src"
printf 'payload-v1\n' > "$plug_src/payload.txt"
sig="$(sha256sum "$plug_src/payload.txt" | awk '{print $1}')"
cat > "$plug_src/plugin.json" <<P
{
  "name": "policy_signed_plugin",
  "version": "0.1.0",
  "description": "signed plugin",
  "signature": {
    "type": "sha256",
    "target": "payload.txt",
    "value": "$sig"
  }
}
P

LM_PLUGIN_DIR="$plug_dir" bash "$LM" plugin install "$plug_src" >/dev/null

policy_ok="$workdir/policy_ok.json"
cat > "$policy_ok" <<JSON
{
  "sha256": {
    "trusted_digests": ["$sig"],
    "revoked_digests": []
  }
}
JSON

LM_PLUGIN_DIR="$plug_dir" LM_PLUGIN_TRUST_POLICY_FILE="$policy_ok" LM_PLUGIN_REQUIRE_TRUST_POLICY=1 \
  bash "$LM" plugin verify policy_signed_plugin >/dev/null

json_ok="$(LM_PLUGIN_DIR="$plug_dir" LM_PLUGIN_TRUST_POLICY_FILE="$policy_ok" LM_PLUGIN_REQUIRE_TRUST_POLICY=1 bash "$LM" plugin verify policy_signed_plugin --json)"
JSON_OUT="$json_ok" python3 - <<'PY'
import json, os
o = json.loads(os.environ["JSON_OUT"])
assert o["ok"] is True
assert o["signature_ok"] is True
assert o["trust_policy_applied"] is True
assert o["require_trust_policy"] is True
PY

policy_revoked="$workdir/policy_revoked.json"
cat > "$policy_revoked" <<JSON
{
  "sha256": {
    "trusted_digests": ["$sig"],
    "revoked_digests": ["$sig"]
  }
}
JSON
set +e
LM_PLUGIN_DIR="$plug_dir" LM_PLUGIN_TRUST_POLICY_FILE="$policy_revoked" \
  bash "$LM" plugin verify policy_signed_plugin >/dev/null 2>&1
rc_revoked=$?
set -e
[[ "$rc_revoked" -eq 2 ]] || {
  echo "expected plugin verify failure rc=2 for revoked digest, got rc=$rc_revoked" >&2
  exit 1
}

missing_policy="$workdir/does_not_exist.json"
set +e
LM_PLUGIN_DIR="$plug_dir" LM_PLUGIN_TRUST_POLICY_FILE="$missing_policy" LM_PLUGIN_REQUIRE_TRUST_POLICY=1 \
  bash "$LM" plugin verify policy_signed_plugin >/dev/null 2>&1
rc_missing=$?
set -e
[[ "$rc_missing" -eq 2 ]] || {
  echo "expected plugin verify failure rc=2 for missing required policy, got rc=$rc_missing" >&2
  exit 1
}

echo "plugin verify trust policy ok"
