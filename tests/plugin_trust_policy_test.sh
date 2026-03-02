#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

plugins_json="$workdir/plugins.json"
cat > "$plugins_json" <<'JSON'
[
  {
    "name": "policy_plugin",
    "version": "1.0.0",
    "source": "/tmp/policy_plugin",
    "trust": "verified"
  }
]
JSON

digest="$(sha256sum "$plugins_json" | awk '{print $1}')"
index_file="$workdir/index.json"
cat > "$index_file" <<JSON
{
  "plugins": [
    {
      "name": "policy_plugin",
      "version": "1.0.0",
      "source": "/tmp/policy_plugin",
      "trust": "verified"
    }
  ],
  "attestation": {
    "type": "sha256",
    "target": "plugins.json",
    "value": "$digest"
  }
}
JSON

policy_ok="$workdir/policy_ok.json"
cat > "$policy_ok" <<JSON
{
  "sha256": {
    "trusted_digests": ["$digest"],
    "revoked_digests": []
  }
}
JSON

LM_PLUGIN_TRUST_POLICY_FILE="$policy_ok" \
  LM_PLUGIN_REQUIRE_TRUST_POLICY=1 \
  bash "$LM" plugin verify-index --index "$index_file" --strict >/dev/null

json_ok="$(LM_PLUGIN_TRUST_POLICY_FILE="$policy_ok" LM_PLUGIN_REQUIRE_TRUST_POLICY=1 bash "$LM" plugin verify-index --index "$index_file" --json --strict)"
JSON_OUT="$json_ok" python3 - <<'PY'
import json, os
o = json.loads(os.environ["JSON_OUT"])
assert o["ok"] is True
assert o.get("trust_policy_applied") is True
assert o.get("require_trust_policy") is True
PY

policy_revoked="$workdir/policy_revoked.json"
cat > "$policy_revoked" <<JSON
{
  "sha256": {
    "trusted_digests": ["$digest"],
    "revoked_digests": ["$digest"]
  }
}
JSON
set +e
LM_PLUGIN_TRUST_POLICY_FILE="$policy_revoked" bash "$LM" plugin verify-index --index "$index_file" --strict >/dev/null 2>&1
rc_revoked=$?
set -e
[[ "$rc_revoked" -eq 2 ]] || {
  echo "expected revoked digest strict failure rc=2, got rc=$rc_revoked" >&2
  exit 1
}

policy_untrusted="$workdir/policy_untrusted.json"
cat > "$policy_untrusted" <<'JSON'
{
  "sha256": {
    "trusted_digests": ["deadbeef"],
    "revoked_digests": []
  }
}
JSON
set +e
LM_PLUGIN_TRUST_POLICY_FILE="$policy_untrusted" bash "$LM" plugin verify-index --index "$index_file" --strict >/dev/null 2>&1
rc_untrusted=$?
set -e
[[ "$rc_untrusted" -eq 2 ]] || {
  echo "expected untrusted digest strict failure rc=2, got rc=$rc_untrusted" >&2
  exit 1
}

missing_policy="$workdir/does_not_exist.json"
set +e
LM_PLUGIN_TRUST_POLICY_FILE="$missing_policy" LM_PLUGIN_REQUIRE_TRUST_POLICY=1 \
  bash "$LM" plugin verify-index --index "$index_file" --strict >/dev/null 2>&1
rc_missing=$?
set -e
[[ "$rc_missing" -eq 2 ]] || {
  echo "expected missing required trust policy strict failure rc=2, got rc=$rc_missing" >&2
  exit 1
}

echo "plugin trust policy ok"
