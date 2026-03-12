#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
workdir="$(mktemp -d "${TMPDIR:-/tmp}/lm_wrapper_bad_index.XXXXXX")"
cleanup(){ rm -rf "$workdir"; }
trap cleanup EXIT

cfg="$workdir/cfg"
log_dir="$workdir/logs"
summary_dir="$workdir/summary"
state_dir="$workdir/state"
mkdir -p "$cfg" "$log_dir" "$summary_dir" "$state_dir"

printf '%s\n' localhost > "$cfg/servers.txt"
: > "$cfg/excluded.txt"

index_file="$state_dir/run_index.jsonl"
cat > "$index_file" <<'EOF'
{"run_id":"prev-run","timestamp":"2026-03-10T00:00:00+0000","overall":"OK","exit_code":0,"hosts":{"ok":1,"warn":0,"crit":0,"unknown":0,"skipped":0}}
not-json
EOF

LM_TEST_MODE=1 \
LM_CFG_DIR="$cfg" \
LOG_DIR="$log_dir" \
SUMMARY_DIR="$summary_dir" \
LM_STATE_DIR="$state_dir" \
LM_MONITORS="health_monitor.sh" \
bash "$ROOT_DIR/run_full_health_monitor.sh" >/dev/null 2>&1 || true

line_count="$(wc -l < "$index_file" | tr -d ' ')"
[[ "$line_count" -eq 2 ]] || {
  echo "wrapper should leave corrupt run index untouched, got $line_count lines" >&2
  cat "$index_file" >&2
  exit 1
}

grep -q '^not-json$' "$index_file" || {
  echo "wrapper should preserve invalid run-index line" >&2
  cat "$index_file" >&2
  exit 1
}

latest_log="$(find "$log_dir" -maxdepth 1 -type f -name 'full_health_monitor_*.log' ! -name '*latest*' | sort | head -n 1)"
[[ -n "$latest_log" ]] || {
  echo "wrapper logfile missing" >&2
  exit 1
}

grep -q 'wrapper run index update skipped due to invalid JSON lines' "$latest_log" || {
  echo "expected wrapper run-index warning in logfile" >&2
  cat "$latest_log" >&2
  exit 1
}

echo "wrapper invalid run index preserve ok"
