#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

cfg="$workdir/etc_linux_maint"
summary_dir="$workdir/logs"
mkdir -p "$cfg/baselines/ports" "$cfg/baselines/configs" "$cfg/baselines/users" "$cfg/baselines/sudoers" "$summary_dir"

printf 'tcp|22|sshd\n' > "$cfg/baselines/ports/localhost.ports"
printf 'sha256|abc|/etc/ssh/sshd_config\n' > "$cfg/baselines/configs/localhost.hashes"
printf 'root\n' > "$cfg/baselines/users/localhost.users"
printf 'deadbeef\n' > "$cfg/baselines/sudoers/localhost.sudoers"
printf '/etc/ssh/sshd_config\n' > "$cfg/config_paths.txt"

old_epoch="$(date -d '60 days ago' +%s)"
fresh_epoch="$(date -d '10 days ago' +%s)"
touch -d "@$old_epoch" "$cfg/baselines/ports/localhost.ports" \
  "$cfg/baselines/configs/localhost.hashes" \
  "$cfg/baselines/users/localhost.users"
touch -d "@$fresh_epoch" "$cfg/baselines/sudoers/localhost.sudoers"

cat > "$summary_dir/full_health_monitor_summary_latest.log" <<'EOF'
monitor=ports_baseline_monitor host=localhost status=WARN reason=ports_baseline_changed new=1 removed=0
monitor=config_drift_monitor host=localhost status=WARN reason=config_drift_changed modified=1 added=0 removed=0
monitor=user_monitor host=localhost status=OK reason=baseline_updated anomalies=0
EOF

set +e
json_out="$(
  LM_CFG_DIR="$cfg" \
  SUMMARY_DIR="$summary_dir" \
  LOG_DIR="$summary_dir" \
  "$ROOT_DIR/bin/linux-maint" baseline refresh --plan --json --stale-days 30 --local-only --kinds ports,configs,sudoers
)"
rc=$?
set -e
[[ "$rc" -eq 1 ]] || {
  echo "expected baseline refresh plan rc=1, got $rc" >&2
  echo "$json_out" >&2
  exit 1
}

printf '%s' "$json_out" | python3 "$ROOT_DIR/tools/json_schema_validate.py" "$ROOT_DIR/docs/schemas/baseline_refresh_plan.json"

python3 - <<'PY' "$json_out" "$cfg"
import json
import sys
from pathlib import Path

payload = json.loads(sys.argv[1])
cfg = Path(sys.argv[2])

assert payload["baseline_refresh_plan_json_contract_version"] == 1, payload
assert payload["stale_days"] == 30, payload
assert payload["local_only"] is True, payload
assert payload["summary"]["selected_kinds"] == 3, payload
assert payload["summary"]["refresh_candidates"] == 2, payload
assert payload["summary"]["blocked"] == 0, payload
assert payload["summary"]["clean"] == 1, payload
items = {item["kind"]: item for item in payload["items"]}
assert items["ports"]["recommended_refresh"] is True, items["ports"]
assert "stale" in items["ports"]["refresh_reasons"], items["ports"]
assert "ports_baseline_changed" in items["ports"]["refresh_reasons"], items["ports"]
assert items["ports"]["command"] == "linux-maint baseline ports --update --local-only", items["ports"]
assert items["configs"]["recommended_refresh"] is True, items["configs"]
assert items["configs"]["support_file"] == str(cfg / "config_paths.txt"), items["configs"]
assert "config_drift_changed" in items["configs"]["refresh_reasons"], items["configs"]
assert items["sudoers"]["recommended_refresh"] is False, items["sudoers"]
assert payload["warnings"], payload
assert payload["result"] == "WARN", payload
PY

echo "baseline refresh plan ok"
