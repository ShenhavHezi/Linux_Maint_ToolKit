#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"
TMPDIR="${TMPDIR:-/tmp}"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

cfg="$workdir/etc_linux_maint"
state="$workdir/state"
mkdir -p "$cfg" "$state"
printf '%s\n' localhost > "$cfg/servers.txt"
: > "$cfg/excluded.txt"
: > "$cfg/services.txt"

export LM_CFG_DIR="$cfg"
export LM_STATE_DIR="$state"
export LM_LOCKDIR="$workdir/lock"

logdir="$ROOT_DIR/.logs"
mkdir -p "$logdir"

ts="2026-02-24_000000"
summary_file="$logdir/full_health_monitor_summary_${ts}.log"
summary_latest="$logdir/full_health_monitor_summary_latest.log"
log_file="$logdir/full_health_monitor_${ts}.log"
status_file="$logdir/last_status_full"
run_index="$state/run_index.jsonl"

cat > "$summary_file" <<'EOF'
monitor=health_monitor host=runner status=OK node=runner hosts=1 unreachable=0 report_lines=1
EOF
ln -sf "$(basename "$summary_file")" "$summary_latest"
cat > "$log_file" <<'EOF'
RUNTIME monitor=health_monitor ms=12
SUMMARY_RESULT overall=OK ok=1 warn=0 crit=0 unknown=0 skipped=0
SUMMARY_HOSTS ok=1 warn=0 crit=0 unknown=0 skipped=0
EOF
cat > "$status_file" <<'EOF'
overall=OK
exit_code=0
EOF
cat > "$run_index" <<'EOF'
{"timestamp":"2026-02-24T00:00:00Z","overall":"OK","exit_code":0}
EOF

assert_json() {
  local label="$1" out
  shift
  out="$("$@" 2>/dev/null || true)"
  if [ -z "$out" ]; then
    echo "ERROR: $label produced empty output" >&2
    exit 1
  fi
  case "$out" in
    \{*|\[* ) ;;
    * ) echo "ERROR: $label produced non-JSON prefix" >&2; echo "$out" >&2; exit 1 ;;
  esac
}

assert_json "status --json" bash "$LM" status --json
assert_json "report --json" bash "$LM" report --json
assert_json "trend --json" bash "$LM" trend --last 1 --json
assert_json "runtimes --json" bash "$LM" runtimes --last 1 --json
assert_json "export --json" bash "$LM" export --json
assert_json "metrics --json" bash "$LM" metrics --json
assert_json "config --json" bash "$LM" config --json
assert_json "doctor --json" bash "$LM" doctor --json
assert_json "self-check --json" bash "$LM" self-check --json
assert_json "history --json" bash "$LM" history --json
assert_json "run-index --json" bash "$LM" run-index --json

echo "json output prefix ok"
