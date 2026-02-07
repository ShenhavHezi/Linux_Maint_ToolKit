#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

if ! sudo -n true >/dev/null 2>&1; then
  echo "sudo without password required for this test" >&2
  exit 0
fi

sudo bash "$ROOT_DIR/run_full_health_monitor.sh" >/dev/null 2>&1 || true

# Pipe JSON to python for validation
sudo bash "$LM" status --json | python3 - <<'PY'
import json, sys
obj=json.load(sys.stdin)
assert 'mode' in obj
assert 'last_status' in obj
assert 'totals' in obj
assert 'problems' in obj
assert isinstance(obj['problems'], list)
for k in ['CRIT','WARN','UNKNOWN','SKIP','OK']:
    assert k in obj['totals']
print('status --json ok')
PY
