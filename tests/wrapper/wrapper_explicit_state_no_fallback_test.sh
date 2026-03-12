#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
workdir="$(mktemp -d "${TMPDIR:-/tmp}/lm_wrapper_state.XXXXXX")"
cfg="$workdir/cfg"
log_dir="$workdir/logs"
summary_dir="$workdir/summary"
state_dir="$workdir/state"
alt_root="/tmp/linux_maint"
alt_file="$alt_root/run_index.jsonl"
backup=""

cleanup(){
  rm -rf "$workdir"
  rm -f "$alt_file"
  if [[ -n "$backup" && -f "$backup" ]]; then
    mkdir -p "$alt_root"
    mv -f "$backup" "$alt_file"
  elif [[ -d "$alt_root" ]]; then
    rmdir "$alt_root" 2>/dev/null || true
  fi
}
trap cleanup EXIT

mkdir -p "$cfg" "$log_dir" "$summary_dir"
printf '%s\n' localhost > "$cfg/servers.txt"
: > "$cfg/excluded.txt"

if [[ -f "$alt_file" ]]; then
  backup="$workdir/original-run-index.jsonl"
  mv -f "$alt_file" "$backup"
fi

mkdir -p "$alt_root"
printf '%s\n' '{"run_id":"stale-run-001","timestamp":"2026-01-01T00:00:00+0000","overall":"OK","exit_code":0,"hosts":{"ok":1,"warn":0,"crit":0,"unknown":0,"skipped":0}}' > "$alt_file"

LM_TEST_MODE=1 \
LM_CFG_DIR="$cfg" \
LOG_DIR="$log_dir" \
SUMMARY_DIR="$summary_dir" \
LM_STATE_DIR="$state_dir" \
LM_MONITORS="health_monitor.sh" \
bash "$ROOT_DIR/run_full_health_monitor.sh" >/dev/null 2>&1 || true

index_file="$state_dir/run_index.jsonl"
[[ -f "$index_file" ]] || {
  echo "wrapper run index missing" >&2
  find "$workdir" -maxdepth 3 -type f | sort >&2 || true
  exit 1
}

if grep -q 'stale-run-001' "$index_file"; then
  echo "wrapper still seeded explicit LM_STATE_DIR from legacy run index" >&2
  cat "$index_file" >&2
  exit 1
fi

line_count="$(wc -l < "$index_file" | tr -d ' ')"
[[ "$line_count" -eq 1 ]] || {
  echo "expected exactly one fresh wrapper run-index entry, got $line_count" >&2
  cat "$index_file" >&2
  exit 1
}

echo "wrapper explicit state no fallback ok"
