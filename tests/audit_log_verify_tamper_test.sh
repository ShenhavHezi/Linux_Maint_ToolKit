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
LM_AUDIT_LOG="$audit_file" bash "$LM" audit-log --verify >/dev/null

# Tamper with first event details without recomputing chain hash.
python3 - "$audit_file" <<'PY'
import json, sys
path = sys.argv[1]
rows = []
with open(path, "r", encoding="utf-8", errors="ignore") as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        rows.append(json.loads(line))
if rows:
    rows[0]["details"] = "tampered=true"
with open(path, "w", encoding="utf-8") as f:
    for row in rows:
        f.write(json.dumps(row, sort_keys=True) + "\n")
PY

set +e
LM_AUDIT_LOG="$audit_file" bash "$LM" audit-log --verify >/dev/null 2>&1
rc=$?
set -e
[[ "$rc" -eq 2 ]] || {
  echo "expected audit-log --verify tamper failure rc=2, got rc=$rc" >&2
  exit 1
}

json_out="$(LM_AUDIT_LOG="$audit_file" bash "$LM" audit-log --verify --json 2>/dev/null || true)"
JSON_OUT="$json_out" python3 - <<'PY'
import json, os
o = json.loads(os.environ["JSON_OUT"])
assert o["valid"] is False
errs = o.get("errors") or []
assert any("chain_hash mismatch" in e for e in errs)
PY

echo "audit log verify tamper ok"
