#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

cfg_dir="$workdir/etc"
index_file="$workdir/run_index.jsonl"
mkdir -p "$cfg_dir"
printf '%s\n' localhost > "$cfg_dir/servers.txt"
: > "$cfg_dir/excluded.txt"
: > "$cfg_dir/services.txt"

cat > "$index_file" <<'EOF'
{"run_id":"ok-run-001","timestamp":"2026-03-11T00:00:00+0000","overall":"OK","exit_code":0,"hosts":{"ok":1,"warn":0,"crit":0,"unknown":0,"skipped":0}}
{not-json
EOF

set +e
out="$(LM_CFG_DIR="$cfg_dir" LM_RUN_INDEX_FILE="$index_file" bash "$LM" run --resume latest --plan --local-only 2>&1)"
rc=$?
set -e

if [[ "$rc" -ne 2 ]]; then
  echo "expected run resume invalid index rc=2, got rc=$rc" >&2
  echo "$out" >&2
  exit 1
fi

printf '%s\n' "$out" | grep -q '^ERROR: run --resume latest requires valid JSON lines in run index: ' || {
  echo "unexpected run resume invalid index output" >&2
  echo "$out" >&2
  exit 1
}

echo "run resume invalid index ok"
