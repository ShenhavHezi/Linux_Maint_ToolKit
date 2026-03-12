#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

cat > "$tmp_dir/run_index.jsonl" <<'EOF'
{"timestamp":"2026-02-19T10:00:00+0000","overall":"OK","exit_code":0,"hosts":{"ok":10,"warn":0,"crit":0,"unknown":0,"skipped":0}}
{not-json
EOF

set +e
out="$(LM_STATE_DIR="$tmp_dir" bash "$LM" history --last 2 --json 2>&1)"
rc=$?
set -e

if [[ "$rc" -ne 2 ]]; then
  echo "expected history invalid run index rc=2, got rc=$rc" >&2
  echo "$out" >&2
  exit 1
fi

grep -q '^ERROR: history requires valid JSON lines in run index: ' <<<"$out" || {
  echo "unexpected history invalid run index output" >&2
  echo "$out" >&2
  exit 1
}

echo "history invalid run index ok"
