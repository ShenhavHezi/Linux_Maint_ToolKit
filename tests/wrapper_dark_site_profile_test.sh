#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

cfg_dir="$workdir/etc_linux_maint"
log_dir="$workdir/logs"
mon_dir="$workdir/monitors"
mkdir -p "$cfg_dir" "$log_dir" "$mon_dir"

printf 'localhost\n' > "$cfg_dir/servers.txt"
: > "$cfg_dir/excluded.txt"
printf 'sshd\n' > "$cfg_dir/services.txt"

cat > "$mon_dir/env_probe.sh" <<'MON'
#!/usr/bin/env bash
set -euo pipefail
. "${LINUX_MAINT_LIB:-/usr/local/lib/linux_maint.sh}" || exit 1
lm_summary "env_probe" "localhost" "OK" reason=probe local_only="${LM_LOCAL_ONLY:-unset}" notify_change="${LM_NOTIFY_ONLY_ON_CHANGE:-unset}"
MON
chmod +x "$mon_dir/env_probe.sh"

run_case() {
  local name="$1"
  local expected_local="$2"
  local expected_timeout="$3"
  local expected_notify="$4"
  shift 4

  rm -f "$log_dir"/full_health_monitor_*.log

  # shellcheck disable=SC2086
  env $@ \
    LM_MONITORS="env_probe.sh" \
    LM_CFG_DIR="$cfg_dir" \
    SCRIPTS_DIR="$mon_dir" \
    LOG_DIR="$log_dir" \
    SUMMARY_DIR="$log_dir" \
    bash "$ROOT_DIR/run_full_health_monitor.sh" >/dev/null

  latest_log="$(find "$log_dir" -maxdepth 1 -type f -name 'full_health_monitor_*.log' ! -name '*summary*' | sort | tail -n 1)"
  [ -n "$latest_log" ] || { echo "missing wrapper log for case $name" >&2; exit 1; }

  line="$(grep 'monitor=env_probe ' "$latest_log" | tail -n 1 || true)"
  [ -n "$line" ] || { echo "missing env_probe summary for case $name" >&2; tail -n 80 "$latest_log" >&2; exit 1; }

  timeout_line="$(grep 'MONITOR_TIMEOUT_SECS=' "$latest_log" | tail -n 1 || true)"
  [ -n "$timeout_line" ] || { echo "missing MONITOR_TIMEOUT_SECS header for case $name" >&2; tail -n 80 "$latest_log" >&2; exit 1; }

  echo "$line" | grep -q " local_only=${expected_local}\b" || { echo "unexpected local_only in $name: $line" >&2; exit 1; }
  echo "$line" | grep -q " notify_change=${expected_notify}\b" || { echo "unexpected notify_change in $name: $line" >&2; exit 1; }
  echo "$timeout_line" | grep -q "MONITOR_TIMEOUT_SECS=${expected_timeout}\b" || { echo "unexpected timeout in $name: $timeout_line" >&2; exit 1; }
}

run_case "default" "unset" "600" "unset"
run_case "dark_site_defaults" "true" "300" "1" LM_DARK_SITE=true
run_case "dark_site_override" "false" "999" "0" LM_DARK_SITE=true LM_LOCAL_ONLY=false MONITOR_TIMEOUT_SECS=999 LM_NOTIFY_ONLY_ON_CHANGE=0

echo "wrapper dark-site profile ok"
