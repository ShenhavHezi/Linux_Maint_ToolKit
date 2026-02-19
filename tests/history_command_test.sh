#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

cat > "$tmp_dir/run_index.jsonl" <<'EOF'
{"timestamp":"2026-02-19T10:00:00+0000","overall":"OK","exit_code":0,"hosts":{"ok":10,"warn":0,"crit":0,"unknown":0,"skipped":0}}
{"timestamp":"2026-02-19T11:00:00+0000","overall":"WARN","exit_code":1,"hosts":{"ok":9,"warn":1,"crit":0,"unknown":0,"skipped":0}}
EOF

out="$(LM_STATE_DIR="$tmp_dir" bash "$LM" history --last 2 2>&1 || true)"
printf '%s\n' "$out" | grep -q '^=== Last 2 runs' || {
  echo "history header missing" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q 'overall=WARN' || {
  echo "history output missing expected run" >&2
  echo "$out" >&2
  exit 1
}

json_out="$(LM_STATE_DIR="$tmp_dir" bash "$LM" history --last 2 --json 2>/dev/null || true)"
printf '%s\n' "$json_out" | grep -q '"runs"' || {
  echo "history --json missing runs key" >&2
  echo "$json_out" >&2
  exit 1
}

echo "history command ok"
