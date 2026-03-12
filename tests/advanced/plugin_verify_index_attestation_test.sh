#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

plugins_json="$workdir/plugins.json"
cat > "$plugins_json" <<'JSON'
[
  {
    "name": "attested_plugin",
    "version": "1.0.0",
    "source": "/tmp/attested_plugin",
    "trust": "verified"
  }
]
JSON

sha="$(sha256sum "$plugins_json" | awk '{print $1}')"
index_file="$workdir/index.json"
cat > "$index_file" <<JSON
{
  "plugins": [
    {
      "name": "attested_plugin",
      "version": "1.0.0",
      "source": "/tmp/attested_plugin",
      "trust": "verified"
    }
  ],
  "attestation": {
    "type": "sha256",
    "target": "plugins.json",
    "value": "$sha"
  }
}
JSON

bash "$LM" plugin verify-index --index "$index_file" --strict >/dev/null

json_ok="$(bash "$LM" plugin verify-index --index "$index_file" --json --strict)"
JSON_OUT="$json_ok" python3 - <<'PY'
import json, os
o = json.loads(os.environ["JSON_OUT"])
assert o["ok"] is True
a = o.get("attestation") or {}
assert a.get("present") is True
assert a.get("verified") is True
assert a.get("type") == "sha256"
PY

# Tamper attested target and ensure strict mode fails.
cat > "$plugins_json" <<'JSON'
[
  {
    "name": "attested_plugin",
    "version": "1.0.1",
    "source": "/tmp/attested_plugin",
    "trust": "verified"
  }
]
JSON

set +e
bash "$LM" plugin verify-index --index "$index_file" --strict >/dev/null 2>&1
rc_bad=$?
set -e
[[ "$rc_bad" -eq 2 ]] || {
  echo "expected verify-index strict failure rc=2 on tamper, got rc=$rc_bad" >&2
  exit 1
}

# Require attestation should fail when index has no attestation block.
no_attest="$workdir/index_no_attest.json"
cat > "$no_attest" <<'JSON'
{
  "plugins": [
    { "name": "plain_plugin", "version": "1.0.0", "source": "/tmp/plain_plugin" }
  ]
}
JSON
set +e
LM_PLUGIN_REQUIRE_ATTEST=1 bash "$LM" plugin verify-index --index "$no_attest" --strict >/dev/null 2>&1
rc_req=$?
set -e
[[ "$rc_req" -eq 2 ]] || {
  echo "expected verify-index strict failure rc=2 when attestation required, got rc=$rc_req" >&2
  exit 1
}

echo "plugin verify-index attestation ok"
