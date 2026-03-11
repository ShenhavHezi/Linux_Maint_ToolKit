#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

cfg_dir="$workdir/etc"
state_dir="$workdir/state"
mkdir -p "$cfg_dir" "$state_dir"
printf '%s\n' localhost > "$cfg_dir/servers.txt"
: > "$cfg_dir/excluded.txt"
: > "$cfg_dir/services.txt"

resume_id="resume-invalid-001"
cat > "$state_dir/run_state_${resume_id}.log" <<'EOF'
run_id=resume-invalid-001
started=2026-03-11T00:00:00Z
monitor=health_monitor status=OK
EOF

set +e
out="$(LM_CFG_DIR="$cfg_dir" LM_STATE_DIR="$state_dir" bash "$LM" run --resume "$resume_id" --plan --local-only 2>&1)"
rc=$?
set -e

if [[ "$rc" -ne 2 ]]; then
  echo "expected run resume invalid state rc=2, got rc=$rc" >&2
  echo "$out" >&2
  exit 1
fi

printf '%s\n' "$out" | grep -q "^ERROR: run --resume requires valid resume state file: $state_dir/run_state_${resume_id}.log (invalid monitor line at line 3)$" || {
  echo "unexpected run resume invalid state output" >&2
  echo "$out" >&2
  exit 1
}

echo "run resume invalid state ok"
