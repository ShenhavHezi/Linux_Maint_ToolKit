#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

s1="$workdir/status1.json"
s2="$workdir/status2.json"
cat > "$s1" <<'JSON'
{
  "last_status": { "overall": "WARN" },
  "totals": { "CRIT": 1, "WARN": 2, "UNKNOWN": 0, "SKIP": 1, "OK": 5 }
}
JSON
cat > "$s2" <<'JSON'
{
  "last_status": { "overall": "OK" },
  "totals": { "CRIT": 0, "WARN": 3, "UNKNOWN": 1, "SKIP": 0, "OK": 9 }
}
JSON

json_out="$(bash "$LM" federate --input "$s1,$s2" --json 2>/dev/null || true)"
JSON_OUT="$json_out" python3 - <<'PY'
import json, os
obj = json.loads(os.environ["JSON_OUT"])
assert obj["federation_contract_version"] == 1
t = obj["totals"]
assert int(t["CRIT"]) == 1
assert int(t["WARN"]) == 5
assert int(t["UNKNOWN"]) == 1
assert int(t["SKIP"]) == 1
assert int(t["OK"]) == 14
assert len(obj["clusters"]) == 2
PY

text_out="$(bash "$LM" federate --input "$s1,$s2" 2>/dev/null || true)"
printf '%s\n' "$text_out" | grep -q 'TOTAL CRIT=1 WARN=5 UNKNOWN=1 SKIP=1 OK=14' || {
  echo "federate text totals mismatch" >&2
  echo "$text_out" >&2
  exit 1
}

echo "federate command ok"
