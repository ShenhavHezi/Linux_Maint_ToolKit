#!/usr/bin/env bash
set -euo pipefail

TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

cfg_dir="$workdir/etc"
log_dir="$workdir/logs"
summary_dir="$workdir/summary"
state_dir="$workdir/state"
mkdir -p "$cfg_dir" "$log_dir" "$summary_dir" "$state_dir"
printf '%s\n' localhost > "$cfg_dir/servers.txt"
: > "$cfg_dir/excluded.txt"

cat > "$cfg_dir/monitor_privilege_policy.conf" <<'P'
health_monitor=allow_sudo
P

LM_MONITORS="health_monitor.sh" \
LM_TEST_MODE=1 \
LM_CFG_DIR="$cfg_dir" \
LM_SERVERLIST="$cfg_dir/servers.txt" \
LM_EXCLUDED="$cfg_dir/excluded.txt" \
LOG_DIR="$log_dir" \
SUMMARY_DIR="$summary_dir" \
LM_STATE_DIR="$state_dir" \
LM_LOCAL_ONLY=true \
bash "$ROOT_DIR/run_full_health_monitor.sh" >/dev/null 2>&1 || true

summary_json="$summary_dir/full_health_monitor_summary_latest.json"
[[ -s "$summary_json" ]] || {
  echo "missing summary json: $summary_json" >&2
  exit 1
}

python3 "$ROOT_DIR/tools/json_schema_validate.py" "$ROOT_DIR/docs/schemas/summary.json" < "$summary_json"

python3 - "$summary_json" "$(id -u)" <<'PY'
import json, sys

path, euid = sys.argv[1:3]
with open(path, "r", encoding="utf-8") as f:
    obj = json.load(f)

priv = obj.get("privilege")
assert isinstance(priv, dict), "missing privilege object"
summary = priv.get("summary") or {}
assert summary.get("total") == 1, summary
assert summary.get("ok") == 1, summary
assert summary.get("violations") == 0, summary

monitors = priv.get("monitors") or []
assert len(monitors) == 1, monitors
row = monitors[0]
assert row.get("monitor") == "health_monitor", row
assert row.get("policy") == "allow_sudo", row
assert row.get("result") == "ok", row
assert str(row.get("euid")) == euid, row
PY

run_state_file="$(find "$state_dir" -maxdepth 1 -type f -name 'run_state_*.log' -print 2>/dev/null | head -n 1 || true)"
[[ -n "$run_state_file" && -s "$run_state_file" ]] || {
  echo "missing run state file" >&2
  exit 1
}
grep -q 'privilege_policy=allow_sudo privilege_result=ok' "$run_state_file" || {
  echo "run state missing privilege telemetry" >&2
  cat "$run_state_file" >&2
  exit 1
}

report_json="$(LOG_DIR="$log_dir" SUMMARY_DIR="$summary_dir" LM_CFG_DIR="$cfg_dir" bash "$LM" report --json)"
printf '%s' "$report_json" | python3 "$ROOT_DIR/tools/json_schema_validate.py" "$ROOT_DIR/docs/schemas/report.json"
printf '%s' "$report_json" | python3 -c 'import json,sys; o=json.load(sys.stdin); p=o.get("privilege") or {}; assert p.get("summary",{}).get("ok")==1; assert p.get("monitors",[{}])[0].get("policy")=="allow_sudo"'

report_text="$(LOG_DIR="$log_dir" SUMMARY_DIR="$summary_dir" LM_CFG_DIR="$cfg_dir" NO_COLOR=1 bash "$LM" report)"
printf '%s\n' "$report_text" | grep -q '^privilege policy$' || {
  echo "report missing privilege policy section" >&2
  echo "$report_text" >&2
  exit 1
}
printf '%s\n' "$report_text" | grep -q 'violations=0' || {
  echo "report missing privilege violation count" >&2
  echo "$report_text" >&2
  exit 1
}

echo "run privilege telemetry ok"
