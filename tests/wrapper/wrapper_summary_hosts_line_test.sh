#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
workdir="$(mktemp -d "${TMPDIR:-/tmp}/lm_summary_hosts.XXXXXX")"
cleanup(){ rm -rf "$workdir"; }
trap cleanup EXIT

cfg="$workdir/cfg"
log_dir="$workdir/logs"
summary_dir="$workdir/summary"
state_dir="$workdir/state"
mkdir -p "$cfg" "$log_dir" "$summary_dir" "$state_dir"

printf '%s\n' localhost > "$cfg/servers.txt"
: > "$cfg/excluded.txt"
cat > "$cfg/linux-maint.conf.example" <<'EOF_CONF'
LM_DARK_SITE=false
EOF_CONF

LM_TEST_MODE=1 \
LM_CFG_DIR="$cfg" \
LOG_DIR="$log_dir" \
SUMMARY_DIR="$summary_dir" \
LM_STATE_DIR="$state_dir" \
LM_MONITORS="config_validate.sh" \
bash "$ROOT_DIR/run_full_health_monitor.sh" >/dev/null 2>&1 || true

log_file="$(find "$log_dir" -maxdepth 1 -type f -name 'full_health_monitor_*.log' ! -name '*latest*' | sort | head -n 1)"
summary_file="$(find "$summary_dir" -maxdepth 1 -type f -name 'full_health_monitor_summary_*.log' ! -name '*latest*' | sort | head -n 1)"

if [ -z "$log_file" ] || [ -z "$summary_file" ]; then
  echo "wrapper artifacts missing" >&2
  find "$workdir" -maxdepth 3 -type f | sort >&2 || true
  exit 1
fi

status="$(awk '
  /^monitor=config_validate / {
    for (i = 1; i <= NF; i++) {
      split($i, a, "=")
      if (a[1] == "status") {
        print a[2]
        exit
      }
    }
  }
' "$summary_file")"

case "$status" in
  OK) expected='SUMMARY_HOSTS ok=1 warn=0 crit=0 unknown=0 skipped=0' ;;
  WARN) expected='SUMMARY_HOSTS ok=0 warn=1 crit=0 unknown=0 skipped=0' ;;
  CRIT) expected='SUMMARY_HOSTS ok=0 warn=0 crit=1 unknown=0 skipped=0' ;;
  UNKNOWN) expected='SUMMARY_HOSTS ok=0 warn=0 crit=0 unknown=1 skipped=0' ;;
  SKIP) expected='SUMMARY_HOSTS ok=0 warn=0 crit=0 unknown=0 skipped=1' ;;
  *)
    echo "unexpected config_validate status: $status" >&2
    cat "$log_file" >&2 || true
    exit 1
    ;;
esac

grep -Fq "$expected" "$log_file" || {
  echo "summary hosts line malformed" >&2
  cat "$log_file" >&2
  exit 1
}

echo "wrapper summary hosts line ok"
