#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

repo_logs="$ROOT_DIR/.logs"
workdir="$(mktemp -d -p "$TMPDIR")"
backup="$workdir/logs_backup"

cleanup() {
  rm -rf "$repo_logs" 2>/dev/null || true
  if [[ -d "$backup" ]]; then
    mv "$backup" "$repo_logs"
  fi
  rm -rf "$workdir"
}
trap cleanup EXIT

if [[ -d "$repo_logs" ]]; then
  mv "$repo_logs" "$backup"
fi
mkdir -p "$repo_logs"

cfg="$workdir/etc_linux_maint"
mkdir -p "$cfg"
printf '%s\n' localhost > "$cfg/servers.txt"
: > "$cfg/excluded.txt"

LM_MONITORS="health_monitor.sh" \
LM_TEST_MODE=1 \
LM_CFG_DIR="$cfg" \
LM_SERVERLIST="$cfg/servers.txt" \
LM_EXCLUDED="$cfg/excluded.txt" \
LM_LOCAL_ONLY=true \
bash "$ROOT_DIR/run_full_health_monitor.sh" >/dev/null 2>&1 || true

summary_json="$repo_logs/full_health_monitor_summary_latest.json"
if [[ ! -s "$summary_json" ]]; then
  echo "missing summary json: $summary_json" >&2
  exit 1
fi

run_id="$(python3 - <<'PY' "$summary_json"
import json,sys
with open(sys.argv[1],"r",encoding="utf-8") as f:
    data=json.load(f)
print(data.get("run_id",""))
PY
)"

if [[ -z "$run_id" ]]; then
  echo "run_id missing in summary json" >&2
  exit 1
fi

status_json="$(bash "$LM" status --json)"
report_json="$(bash "$LM" report --json)"
metrics_json="$(bash "$LM" metrics --json)"

RUN_ID="$run_id" STATUS_JSON="$status_json" REPORT_JSON="$report_json" METRICS_JSON="$metrics_json" python3 - <<'PY'
import json, os, sys
run_id = os.environ.get("RUN_ID","")
def load_env(name):
    raw = os.environ.get(name, "")
    return json.loads(raw) if raw else {}
status = load_env("STATUS_JSON")
report = load_env("REPORT_JSON")
metrics = load_env("METRICS_JSON")
for name, obj in [("status", status), ("report", report), ("metrics", metrics)]:
    if obj.get("run_id") != run_id:
        raise SystemExit(f"run_id mismatch in {name}: {obj.get('run_id')} != {run_id}")
print("run_id propagation ok")
PY
