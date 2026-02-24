#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"
TMPDIR="${TMPDIR:-/tmp}"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

mkdir -p "$ROOT_DIR/.logs"

prev="$workdir/last_summary_monitor_lines.log"
cur="$ROOT_DIR/.logs/full_health_monitor_summary_latest.log"

cat > "$prev" <<'EOF'
monitor=patch_monitor host=host1 status=OK node=runner
monitor=service_monitor host=host1 status=OK node=runner
EOF

cat > "$cur" <<'EOF'
monitor=patch_monitor host=host1 status=WARN node=runner reason=updates_pending
monitor=service_monitor host=host1 status=OK node=runner
monitor=network_monitor host=host2 status=CRIT node=runner reason=ssh_unreachable
EOF

out="$(LM_NOTIFY_STATE_DIR="$workdir" bash "$LM" diff --json 2>/dev/null || true)"

if [ -z "$out" ]; then
  echo "diff --json produced no output" >&2
  exit 1
fi

printf '%s' "$out" | python3 "$ROOT_DIR/tools/json_schema_validate.py" "$ROOT_DIR/docs/schemas/diff.json"
python3 - <<'PY' "$out"
import json,sys
o=json.loads(sys.argv[1])
assert "new_failures" in o
assert "recovered" in o
assert "still_bad" in o
assert "changed" in o
print("diff json schema ok")
PY
