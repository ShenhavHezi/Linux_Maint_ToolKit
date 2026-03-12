#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

cfg_dir="$workdir/etc"
state_dir="$workdir/state"
index_file="$state_dir/run_index.jsonl"
mkdir -p "$cfg_dir" "$state_dir"
printf '%s\n' localhost > "$cfg_dir/servers.txt"
: > "$cfg_dir/excluded.txt"
: > "$cfg_dir/services.txt"

cat > "$index_file" <<'EOF'
{"run_id":"resume-missing-001","timestamp":"2026-03-11T00:00:00+0000","overall":"WARN","exit_code":1,"hosts":{"ok":0,"warn":1,"crit":0,"unknown":0,"skipped":0}}
EOF

set +e
out="$(LM_CFG_DIR="$cfg_dir" LM_STATE_DIR="$state_dir" bash "$LM" run --resume latest --plan --local-only 2>&1)"
rc=$?
set -e

if [[ "$rc" -ne 2 ]]; then
  echo "expected run resume missing state rc=2, got rc=$rc" >&2
  echo "$out" >&2
  exit 1
fi

printf '%s\n' "$out" | grep -q "^ERROR: run --resume requires resume state file: $state_dir/run_state_resume-missing-001.log$" || {
  echo "unexpected run resume missing state output" >&2
  echo "$out" >&2
  exit 1
}

echo "run resume missing state ok"
