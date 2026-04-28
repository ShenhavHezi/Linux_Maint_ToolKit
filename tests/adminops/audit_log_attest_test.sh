#!/usr/bin/env bash
set -euo pipefail

TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'chmod 0644 "$workdir/attestation.json" 2>/dev/null || true; rm -rf "$workdir"' EXIT

audit_file="$workdir/audit.log"
attest_file="$workdir/attestation.json"
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

json_out="$(LM_AUDIT_LOG="$audit_file" bash "$LM" audit-log --attest --json --out "$attest_file")"
printf '%s' "$json_out" | python3 "$ROOT_DIR/tools/json_schema_validate.py" "$ROOT_DIR/docs/schemas/audit_log.json"
python3 "$ROOT_DIR/tools/json_schema_validate.py" "$ROOT_DIR/docs/schemas/audit_log.json" < "$attest_file"

JSON_OUT="$json_out" ATTEST_FILE="$attest_file" AUDIT_FILE="$audit_file" python3 - <<'PY'
import hashlib
import json
import os
import stat
from pathlib import Path

payload = json.loads(os.environ["JSON_OUT"])
attest = json.loads(Path(os.environ["ATTEST_FILE"]).read_text(encoding="utf-8"))
audit_bytes = Path(os.environ["AUDIT_FILE"]).read_bytes()
mode = stat.S_IMODE(Path(os.environ["ATTEST_FILE"]).stat().st_mode)

assert payload == attest
assert payload["audit_attestation_contract_version"] == 1
assert payload["valid"] is True
assert payload["events_checked"] >= 2
assert payload["file_sha256"] == hashlib.sha256(audit_bytes).hexdigest()
assert payload["last_chain_hash"]
assert mode == 0o444, oct(mode)
assert payload["worm_guidance"]["overwrite_refused"] is True
PY

set +e
overwrite_out="$(LM_AUDIT_LOG="$audit_file" bash "$LM" audit-log --attest --out "$attest_file" 2>&1)"
overwrite_rc=$?
set -e
if [[ "$overwrite_rc" -ne 2 ]]; then
  echo "expected audit-log --attest --out overwrite rc=2, got $overwrite_rc" >&2
  echo "$overwrite_out" >&2
  exit 1
fi
printf '%s\n' "$overwrite_out" | grep -q '^ERROR: attestation output already exists: ' || {
  echo "missing overwrite protection error" >&2
  echo "$overwrite_out" >&2
  exit 1
}

echo "audit log attestation ok"
