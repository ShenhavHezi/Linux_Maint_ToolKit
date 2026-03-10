#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
service_file="$ROOT_DIR/packaging/rpm/linux-maint.service"
timer_file="$ROOT_DIR/packaging/rpm/linux-maint.timer"

assert_grep(){
  local pattern="$1" file="$2" message="$3"
  grep -Eq "$pattern" "$file" || {
    echo "$message" >&2
    exit 1
  }
}

assert_not_grep(){
  local pattern="$1" file="$2" message="$3"
  if grep -Eq "$pattern" "$file"; then
    echo "$message" >&2
    exit 1
  fi
}

assert_not_grep 'echo "##active_line' "$service_file" "rpm service unit still contains generated echo markers"
assert_not_grep 'echo "##active_line' "$timer_file" "rpm timer unit still contains generated echo markers"

assert_grep '^\[Unit\]$' "$service_file" "rpm service unit missing [Unit] section"
assert_grep '^Description=Linux maintenance full health monitor$' "$service_file" "rpm service description drifted"
assert_grep '^ExecStart=/usr/sbin/run_full_health_monitor\.sh$' "$service_file" "rpm service ExecStart drifted"
assert_grep '^ReadWritePaths=/var/log /var/log/health /var/lib/linux_maint /var/lock /tmp$' "$service_file" "rpm service writable paths drifted"

assert_grep '^\[Timer\]$' "$timer_file" "rpm timer unit missing [Timer] section"
assert_grep '^OnCalendar=\*-\*-\* 02:15:00$' "$timer_file" "rpm timer schedule drifted"
assert_grep '^Persistent=true$' "$timer_file" "rpm timer must stay persistent"
assert_grep '^\[Install\]$' "$timer_file" "rpm timer unit missing [Install] section"
assert_grep '^WantedBy=timers\.target$' "$timer_file" "rpm timer install target drifted"

echo "rpm systemd units ok"
