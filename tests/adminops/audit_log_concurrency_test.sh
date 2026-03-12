#!/usr/bin/env bash
set -euo pipefail

TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT
audit_file="$workdir/audit.log"

pids=()
for i in $(seq 1 20); do
  LM_AUDIT_LOG="$audit_file" bash "$LM" cm-hook --provider ansible --target "host-$i" --module ping --dry-run >/dev/null 2>&1 &
  pids+=("$!")
done

for pid in "${pids[@]}"; do
  wait "$pid"
done

LM_AUDIT_LOG="$audit_file" bash "$LM" audit-log --verify >/dev/null

verify_json="$(LM_AUDIT_LOG="$audit_file" bash "$LM" audit-log --verify --json 2>/dev/null || true)"
VERIFY_JSON="$verify_json" python3 - <<'PY'
import json, os
o = json.loads(os.environ["VERIFY_JSON"])
assert o["valid"] is True
assert int(o.get("events_checked", 0)) >= 40
PY

echo "audit log concurrency ok"
