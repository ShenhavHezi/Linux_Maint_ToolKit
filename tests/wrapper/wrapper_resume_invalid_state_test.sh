#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
WRAP="$ROOT_DIR/run_full_health_monitor.sh"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

state_dir="$workdir/state"
cfg_dir="$workdir/etc"
log_dir="$workdir/logs"
summary_dir="$workdir/summary"
mkdir -p "$state_dir" "$cfg_dir" "$log_dir" "$summary_dir"

printf '%s\n' localhost > "$cfg_dir/servers.txt"
: > "$cfg_dir/excluded.txt"
: > "$cfg_dir/services.txt"

resume_id="resume-bad-wrapper-001"
state_file="$state_dir/run_state_${resume_id}.log"
cat > "$state_file" <<'EOF'
run_id=wrong-run-id
started=2026-03-02T00:00:00Z
monitor=health_monitor status=OK rc=0 completed_epoch=100
EOF

set +e
out="$(LM_TEST_MODE=1 LM_STATE_DIR="$state_dir" LM_CFG_DIR="$cfg_dir" LOG_DIR="$log_dir" SUMMARY_DIR="$summary_dir" LM_MONITORS="health_monitor.sh preflight_check.sh" LM_RESUME_RUN_ID="$resume_id" LM_RUN_ID="$resume_id" bash "$WRAP" 2>&1)"
rc=$?
set -e

if [[ "$rc" -ne 0 && "$rc" -ne 1 && "$rc" -ne 2 && "$rc" -ne 3 ]]; then
  echo "unexpected rc=$rc" >&2
  echo "$out" >&2
  exit 1
fi

printf '%s\n' "$out" | grep -q "^WARN: resume state invalid for run_id=$resume_id ($state_file): run_id header mismatch (wrong-run-id); running full monitor set$" || {
  echo "missing wrapper invalid resume state warning" >&2
  echo "$out" >&2
  exit 1
}

summary_file="$(find "$summary_dir" -maxdepth 1 -type f -name 'full_health_monitor_summary_*.log' -print 2>/dev/null | head -n 1 || true)"
[[ -n "$summary_file" && -f "$summary_file" ]] || {
  echo "summary file missing" >&2
  echo "$out" >&2
  exit 1
}

if grep -q 'reason=resumed_already_completed' "$summary_file"; then
  echo "invalid resume state should not skip any monitor" >&2
  cat "$summary_file" >&2
  exit 1
fi

grep -q '^monitor=health_monitor ' "$summary_file" || {
  echo "health_monitor should have executed after invalid resume state" >&2
  cat "$summary_file" >&2
  exit 1
}

grep -q '^monitor=preflight_check ' "$summary_file" || {
  echo "preflight_check should have executed after invalid resume state" >&2
  cat "$summary_file" >&2
  exit 1
}

echo "wrapper resume invalid state ok"
