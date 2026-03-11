#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"
workdir="$(mktemp -d "${TMPDIR:-/tmp}/lm_doctor_fix_repo.XXXXXX")"
trap 'rm -rf "$workdir"' EXIT

cfg="$workdir/cfg"
logs="$workdir/logs"
state="$workdir/state"
mkdir -p "$cfg"
printf '%s\n' localhost > "$cfg/servers.txt"
: > "$cfg/excluded.txt"
: > "$cfg/services.txt"

out="$(LM_CFG_DIR="$cfg" LOG_DIR="$logs" LM_STATE_DIR="$state" bash "$LM" doctor --fix --dry-run --yes --json)"
human_out="$(LM_CFG_DIR="$cfg" LOG_DIR="$logs" LM_STATE_DIR="$state" bash "$LM" doctor --fix --dry-run --yes 2>&1)"

python3 - <<'PY' "$out" "$human_out"
import json
import sys

obj = json.loads(sys.argv[1])
human_out = sys.argv[2]
assert obj.get("doctor_json_contract_version") == 1
fix_actions = obj.get("fix_actions")
assert isinstance(fix_actions, list)
assert fix_actions, "expected at least one doctor fix action in dry-run output"
assert any(entry.get("status") == "dry_run" for entry in fix_actions)
assert all((entry.get("target") or "").strip() for entry in fix_actions), "empty doctor fix target leaked into JSON"
assert "- would create: \n" not in human_out
PY

echo "doctor --fix repo-mode non-root ok"
