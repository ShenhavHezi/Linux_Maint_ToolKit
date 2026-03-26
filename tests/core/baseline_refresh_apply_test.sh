#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

cfg="$workdir/etc_linux_maint"
summary_dir="$workdir/logs"
mkdir -p "$cfg/baselines/ports" "$summary_dir"
printf '%s\n' localhost > "$cfg/servers.txt"

base_file="$cfg/baselines/ports/localhost.baseline"
printf 'old\n' > "$base_file"
touch -t 202401010101 "$base_file"
old_mtime="$(stat -c %Y "$base_file")"

cat > "$summary_dir/full_health_monitor_summary_latest.log" <<'EOF'
monitor=ports_baseline_monitor host=localhost status=WARN reason=ports_baseline_changed new=1 removed=0
EOF

set +e
json_out="$(
  LM_CFG_DIR="$cfg" \
  LM_SERVERLIST="$cfg/servers.txt" \
  SUMMARY_DIR="$summary_dir" \
  LOG_DIR="$summary_dir" \
  "$ROOT_DIR/bin/linux-maint" baseline refresh --apply --json --stale-days 1 --local-only --kinds ports
)"
rc=$?
set -e

[[ "$rc" -eq 0 ]] || {
  echo "expected baseline refresh apply rc=0, got $rc" >&2
  echo "$json_out" >&2
  exit 1
}

printf '%s' "$json_out" | python3 "$ROOT_DIR/tools/json_schema_validate.py" "$ROOT_DIR/docs/schemas/baseline_refresh_plan.json"

new_mtime="$(stat -c %Y "$base_file")"
[[ "$new_mtime" -gt "$old_mtime" ]] || {
  echo "expected baseline file mtime to advance" >&2
  ls -l "$base_file" >&2
  exit 1
}

python3 - <<'PY' "$json_out"
import json
import sys

payload = json.loads(sys.argv[1])
assert payload["result"] == "WARN", payload
assert payload["summary"]["refresh_candidates"] == 1, payload
assert payload["apply"]["result"] == "OK", payload
assert payload["apply"]["applied"] == ["ports"], payload
assert payload["apply"]["blocked"] == [], payload
assert payload["apply"]["failed"] == [], payload
PY

echo "baseline refresh apply ok"
