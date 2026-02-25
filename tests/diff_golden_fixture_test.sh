#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

repo_logs="$ROOT_DIR/.logs"
workdir="$(mktemp -d)"
backup="$workdir/logs_backup"
state_dir="$workdir/state"
mkdir -p "$state_dir"

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

# Previous summary (state)
cat > "$state_dir/last_summary_monitor_lines.log" <<'S'
monitor=service_monitor host=web-1 status=OK
monitor=backup_check host=backup-1 status=OK
S

# Current summary (repo log dir)
cat > "$repo_logs/full_health_monitor_summary_latest.log" <<'S'
monitor=service_monitor host=web-1 status=WARN reason=service_inactive
monitor=backup_check host=backup-1 status=CRIT reason=backup_failures
S

out="$(NO_COLOR=1 LM_STATE_DIR="$state_dir" bash "$LM" diff)"
normalized="$(printf '%s
' "$out" | sed -E "s#diff_state_dir=.*#diff_state_dir=<STATE>#; s#diff_prev=.*#diff_prev=<PREV>#; s#diff_cur=.*#diff_cur=<CUR>#")"

expected_file="$ROOT_DIR/tests/fixtures/diff_golden.txt"
if ! diff -u "$expected_file" <(printf '%s
' "$normalized") >/dev/null; then
  echo "diff golden output mismatch" >&2
  diff -u "$expected_file" <(printf '%s
' "$normalized") >&2 || true
  exit 1
fi

echo "diff golden fixture ok"
