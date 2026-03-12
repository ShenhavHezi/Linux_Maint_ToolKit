#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
cfg_dir="$workdir/etc"
alt_root="/tmp/linux_maint"
alt_file="$alt_root/run_index.jsonl"
backup=""
trap '
  rm -rf "$workdir"
  rm -f "$alt_file"
  if [[ -n "$backup" && -f "$backup" ]]; then
    mkdir -p "$alt_root"
    mv -f "$backup" "$alt_file"
  fi
' EXIT

mkdir -p "$cfg_dir"
printf "%s\n" localhost > "$cfg_dir/servers.txt"
: > "$cfg_dir/excluded.txt"
: > "$cfg_dir/services.txt"

if [[ -f "$alt_file" ]]; then
  backup="$workdir/original-run-index.jsonl"
  mv -f "$alt_file" "$backup"
fi

mkdir -p "$alt_root"
printf '%s\n' '{"run_id":"alt-run-001","timestamp":"2026-01-01T00:00:00+0000","overall":"OK","exit_code":0,"hosts":{"ok":1,"warn":0,"crit":0,"unknown":0,"skipped":0}}' > "$alt_file"

missing_state="$workdir/state"
set +e
out="$(LM_CFG_DIR="$cfg_dir" LM_STATE_DIR="$missing_state" bash "$LM" run --resume latest --plan --local-only 2>&1)"
rc=$?
set -e

if [[ "$rc" -ne 2 ]]; then
  echo "expected explicit LM_STATE_DIR to prevent resume fallback, got rc=$rc" >&2
  echo "$out" >&2
  exit 1
fi

printf '%s\n' "$out" | grep -q "^ERROR: unable to resolve --resume target 'latest'$" || {
  echo "unexpected run resume explicit state output" >&2
  echo "$out" >&2
  exit 1
}

echo "run resume explicit state no fallback ok"
