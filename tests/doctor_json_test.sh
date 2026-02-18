#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

out="$("$ROOT_DIR"/bin/linux-maint doctor --json)"

python3 - <<'PY' "$out"
import json
import sys

obj = json.loads(sys.argv[1])

assert isinstance(obj, dict)
for key in ("mode", "cfg_dir", "config", "monitor_gates", "dependencies", "writable_locations", "fix_suggestions", "next_actions"):
    assert key in obj, f"missing key: {key}"

assert isinstance(obj["monitor_gates"], list) and len(obj["monitor_gates"]) >= 1
assert isinstance(obj["dependencies"], list) and len(obj["dependencies"]) >= 1
assert isinstance(obj["writable_locations"], list) and len(obj["writable_locations"]) >= 1
assert isinstance(obj["fix_suggestions"], list)

cfg = obj["config"]
assert "dir_exists" in cfg and "files" in cfg and "hosts_configured" in cfg

print("doctor json ok")
PY
