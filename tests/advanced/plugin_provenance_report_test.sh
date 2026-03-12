#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

plug_src="$workdir/prov-plugin"
plug_dir="$workdir/plugins"
mkdir -p "$plug_src"
printf 'payload-v1\n' > "$plug_src/payload.txt"
plug_digest="$(sha256sum "$plug_src/payload.txt" | awk '{print $1}')"
cat > "$plug_src/plugin.json" <<P
{
  "name": "prov_plugin",
  "version": "0.1.0",
  "description": "provenance plugin",
  "signature": {
    "type": "sha256",
    "target": "payload.txt",
    "value": "$plug_digest"
  }
}
P

LM_PLUGIN_DIR="$plug_dir" bash "$LM" plugin install "$plug_src" >/dev/null

plugins_json="$workdir/plugins.json"
cat > "$plugins_json" <<'JSON'
[
  {
    "name": "prov_plugin",
    "version": "0.1.0",
    "source": "/tmp/prov_plugin",
    "trust": "verified"
  }
]
JSON
idx_digest="$(sha256sum "$plugins_json" | awk '{print $1}')"
index_file="$workdir/index.json"
cat > "$index_file" <<JSON
{
  "plugins": [
    {
      "name": "prov_plugin",
      "version": "0.1.0",
      "source": "/tmp/prov_plugin",
      "trust": "verified"
    }
  ],
  "attestation": {
    "type": "sha256",
    "target": "plugins.json",
    "value": "$idx_digest"
  }
}
JSON

policy_file="$workdir/plugin_trust_policy.json"
cat > "$policy_file" <<JSON
{
  "sha256": {
    "trusted_digests": ["$idx_digest", "$plug_digest"],
    "revoked_digests": []
  }
}
JSON

json_out="$(LM_PLUGIN_DIR="$plug_dir" LM_PLUGIN_TRUST_POLICY_FILE="$policy_file" LM_PLUGIN_REQUIRE_TRUST_POLICY=1 LM_PLUGIN_REQUIRE_ATTEST=1 bash "$LM" plugin provenance-report --index "$index_file" --json --strict)"
JSON_OUT="$json_out" python3 - <<'PY'
import json, os
o = json.loads(os.environ["JSON_OUT"])
assert o["plugin_provenance_contract_version"] == 1
assert o["overall_ok"] is True
s = o.get("summary") or {}
assert s.get("index_ok") is True
assert s.get("plugins_total") == 1
assert s.get("plugins_failed") == 0
PY

out_file="$workdir/provenance_report.json"
LM_PLUGIN_DIR="$plug_dir" LM_PLUGIN_TRUST_POLICY_FILE="$policy_file" LM_PLUGIN_REQUIRE_TRUST_POLICY=1 LM_PLUGIN_REQUIRE_ATTEST=1 \
  bash "$LM" plugin provenance-report --index "$index_file" --out "$out_file" --strict >/dev/null
[[ -s "$out_file" ]] || {
  echo "expected provenance report file to be written" >&2
  exit 1
}

# Tamper plugin; strict provenance should fail.
printf 'payload-v2\n' > "$plug_dir/prov_plugin/payload.txt"
set +e
LM_PLUGIN_DIR="$plug_dir" LM_PLUGIN_TRUST_POLICY_FILE="$policy_file" LM_PLUGIN_REQUIRE_TRUST_POLICY=1 LM_PLUGIN_REQUIRE_ATTEST=1 \
  bash "$LM" plugin provenance-report --index "$index_file" --strict >/dev/null 2>&1
rc_bad=$?
set -e
[[ "$rc_bad" -eq 2 ]] || {
  echo "expected strict provenance failure rc=2 after tamper, got rc=$rc_bad" >&2
  exit 1
}

echo "plugin provenance report ok"
