#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

out="$(sudo -n "$ROOT_DIR/bin/linux-maint" doctor --fix --dry-run --json)"

python3 - <<'PY' "$out"
import json
import sys

obj = json.loads(sys.argv[1])

assert "fix_actions" in obj, "missing fix_actions"
fix_actions = obj["fix_actions"]
assert isinstance(fix_actions, list), "fix_actions not a list"
for entry in fix_actions:
    assert isinstance(entry, dict), "fix_actions entry not an object"
    for key in ("id", "action", "status"):
        assert key in entry, f"missing {key} in fix_actions"

print("doctor fix json ok")
PY
