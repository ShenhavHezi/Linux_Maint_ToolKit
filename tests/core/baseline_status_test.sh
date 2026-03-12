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

# Force old mtimes so staleness is deterministic.
touch -t 202401010101 "$cfg/baselines/ports/localhost.ports" \
  "$cfg/baselines/configs/localhost.hashes" \
  "$cfg/baselines/users/localhost.users" \
  "$cfg/baselines/sudoers/localhost.sudoers"

cat > "$summary_dir/full_health_monitor_summary_latest.log" <<'EOF'
monitor=ports_baseline_monitor host=localhost status=WARN reason=ports_baseline_changed new=1 removed=0
monitor=config_drift_monitor host=localhost status=SKIP reason=baseline_missing modified=0 added=0 removed=0
monitor=user_monitor host=localhost status=OK reason=baseline_updated anomalies=0
EOF

json_out="$(
  LM_CFG_DIR="$cfg" \
  SUMMARY_DIR="$summary_dir" \
  LOG_DIR="$summary_dir" \
  "$ROOT_DIR/bin/linux-maint" baseline status --json --stale-days 1
)"

printf '%s' "$json_out" | python3 "$ROOT_DIR/tools/json_schema_validate.py" "$ROOT_DIR/docs/schemas/baseline_status.json"

python3 - <<'PY' "$json_out" "$cfg"
import json
import sys
from pathlib import Path

payload = json.loads(sys.argv[1])
cfg = Path(sys.argv[2])

assert payload["baseline_status_json_contract_version"] == 1, payload
assert payload["stale_days"] == 1, payload
assert payload["summary"]["stale_items"] == 4, payload
assert payload["summary"]["fresh_items"] == 0, payload
assert payload["summary"]["drift_items"] == 2, payload
assert payload["summary"]["changed_hosts_total"] == 1, payload
assert payload["result"] == "WARN", payload
assert payload["next_steps"], payload
items = {item["kind"]: item for item in payload["items"]}

assert items["ports"]["file_count"] == 1, items["ports"]
assert items["ports"]["stale"] is True, items["ports"]
assert items["ports"]["latest_status"] == "WARN", items["ports"]
assert items["ports"]["latest_reason"] == "ports_baseline_changed", items["ports"]

assert items["configs"]["support_file"] == str(cfg / "config_paths.txt"), items["configs"]
assert items["configs"]["support_exists"] is True, items["configs"]
assert items["configs"]["latest_reason"] == "baseline_missing", items["configs"]

assert items["users"]["latest_status"] == "OK", items["users"]
assert items["sudoers"]["latest_status"] == "OK", items["sudoers"]
assert any(item["kind"] == "ports" for item in payload["attention_items"]), payload
PY

echo "baseline status ok"
