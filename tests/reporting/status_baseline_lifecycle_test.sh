#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

log_dir="$workdir/logs"
cfg_dir="$workdir/cfg"
mkdir -p "$log_dir" "$cfg_dir/baselines/ports" "$cfg_dir/baselines/configs" "$cfg_dir/baselines/users" "$cfg_dir/baselines/sudoers"
printf '%s\n' localhost > "$cfg_dir/servers.txt"
: > "$cfg_dir/excluded.txt"
: > "$cfg_dir/services.txt"
printf '/etc/ssh/sshd_config\n' > "$cfg_dir/config_paths.txt"

printf 'tcp|22|sshd\n' > "$cfg_dir/baselines/ports/localhost.baseline"
printf 'sha256|abc|/etc/ssh/sshd_config\n' > "$cfg_dir/baselines/configs/localhost.hashes"
printf 'root\n' > "$cfg_dir/baselines/users/localhost.users"
printf 'deadbeef\n' > "$cfg_dir/baselines/sudoers/localhost.sudoers"
touch -t 202401010101 "$cfg_dir/baselines/ports/localhost.baseline"

cat > "$log_dir/full_health_monitor_summary_latest.log" <<'EOF'
monitor=ports_baseline_monitor host=localhost status=WARN reason=ports_baseline_changed new=1 removed=0
monitor=service_monitor host=localhost status=WARN reason=service_inactive
EOF

cat > "$log_dir/last_status_full" <<'EOF'
overall=WARN
exit_code=1
timestamp=2026-03-26T10:00:00Z
run_id=run-status-baseline-001
EOF

json_out="$(LOG_DIR="$log_dir" SUMMARY_DIR="$log_dir" LM_CFG_DIR="$cfg_dir" NO_COLOR=1 bash "$LM" status --json 2>&1)"
printf '%s' "$json_out" | python3 -c 'import json,sys; o=json.load(sys.stdin); b=o["baseline"]; assert b["result"]=="WARN"; assert b["summary"]["stale_items"] >= 1; assert b["summary"]["drift_items"] >= 1; assert b["summary"]["changed_hosts_total"] >= 1; assert b["attention_items"]'

human_out="$(LOG_DIR="$log_dir" SUMMARY_DIR="$log_dir" LM_CFG_DIR="$cfg_dir" NO_COLOR=1 bash "$LM" status --table 2>&1 || true)"
for required in \
  '^=== Baseline lifecycle ===$' \
  '^result=WARN$' \
  '^stale_days=30$' \
  '^attention_items=1$' \
  '^next_step_hint=linux-maint baseline ports --update$' \
  '^next_step: linux-maint baseline refresh --plan$' \
  '^baseline_result=WARN$' \
  '^baseline_attention=1$'
do
  printf '%s\n' "$human_out" | grep -q "$required" || {
    echo "status baseline output missing pattern: $required" >&2
    echo "$human_out" >&2
    exit 1
  }
done

echo "status baseline lifecycle ok"
