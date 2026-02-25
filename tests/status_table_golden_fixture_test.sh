#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

repo_logs="$ROOT_DIR/.logs"
workdir="$(mktemp -d)"
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

# Summary files
cat > "$repo_logs/full_health_monitor_summary_latest.log" <<'S'
monitor=service_monitor host=web-1 status=WARN reason=service_inactive
monitor=network_monitor host=web-2 status=CRIT reason=http_failed
monitor=backup_check host=backup-1 status=OK
S

cat > "$repo_logs/full_health_monitor_summary_2026-02-24_000000.log" <<'S'
monitor=service_monitor host=web-1 status=WARN reason=service_inactive
monitor=network_monitor host=web-2 status=CRIT reason=http_failed
monitor=backup_check host=backup-1 status=OK
S

# Status file
cat > "$repo_logs/last_status_full" <<'S'
overall=CRIT
exit_code=2
timestamp=2026-02-24T00:00:00Z
logfile=/var/log/health/full_health_monitor_latest.log
S

# Config files to avoid expected SKIPs
cfg_dir="$workdir/etc"
mkdir -p "$cfg_dir"
cat > "$cfg_dir/network_targets.txt" <<'S'
localhost,ping,1
S
cat > "$cfg_dir/certs.txt" <<'S'
/etc/ssl/certs/ca-bundle.crt
S
cat > "$cfg_dir/ports_baseline.txt" <<'S'
# baseline
S
cat > "$cfg_dir/config_paths.txt" <<'S'
/etc/hosts
S
cat > "$cfg_dir/baseline_users.txt" <<'S'
root
S
cat > "$cfg_dir/baseline_sudoers.txt" <<'S'
root
S
cat > "$cfg_dir/backup_targets.csv" <<'S'
localhost,/var/log,24,1,true
S

out="$(NO_COLOR=1 LOG_DIR="$repo_logs" LM_CFG_DIR="$cfg_dir" bash "$LM" status --table --problems 5 --reasons 5)"
norm_out="$(printf '%s\n' "$out" | sed "s|$ROOT_DIR|<REPO_ROOT>|g")"

expected_file="$ROOT_DIR/tests/fixtures/status_table_golden.txt"
if ! diff -u "$expected_file" <(printf '%s\n' "$norm_out") >/dev/null; then
  echo "status --table golden output mismatch" >&2
  diff -u "$expected_file" <(printf '%s\n' "$norm_out") >&2 || true
  exit 1
fi

echo "status --table golden fixture ok"
