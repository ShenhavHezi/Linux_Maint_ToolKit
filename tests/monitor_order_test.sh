#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"
WRAPPER="$ROOT_DIR/run_full_health_monitor.sh"

# Extract wrapper script order
mapfile -t wrapper_list < <(
  awk '
    BEGIN{in_block=0}
    /^declare -a scripts=\(/ {in_block=1; next}
    in_block==1 {
      if ($0 ~ /\)/) {exit}
      gsub(/#.*/, "", $0)
      if ($0 ~ /"/) {
        gsub(/"/, "", $0)
        gsub(/^[ \t]+|[ \t]+$/, "", $0)
        if ($0 != "") print $0
      }
    }
  ' "$WRAPPER"
)

if [ "${#wrapper_list[@]}" -eq 0 ]; then
  echo "wrapper list empty" >&2
  exit 1
fi

plan_json="$(NO_COLOR=1 "$LM" run --plan --json --local-only)"

WRAPPER_LIST="${wrapper_list[*]}" python3 - "$plan_json" <<'PY'
import json
import os
import sys

plan = json.loads(sys.argv[1])
monitors = plan.get("monitors", [])
wrapper = os.environ.get("WRAPPER_LIST", "").split()

if monitors != wrapper:
    raise SystemExit(f"monitor order mismatch\nplan={monitors}\nwrapper={wrapper}")
print("monitor order ok")
PY

# Validate --only ordering preserved
plan_only_json="$(NO_COLOR=1 "$LM" run --plan --json --local-only --only backup_check,health_monitor)"
python3 - "$plan_only_json" <<'PY'
import json
import sys

plan = json.loads(sys.argv[1])
mons = plan.get("monitors", [])
if mons != ["backup_check.sh", "health_monitor.sh"]:
    raise SystemExit(f"--only ordering mismatch: {mons}")
print("monitor --only ordering ok")
PY

echo "monitor order test ok"
