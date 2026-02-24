#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

cat > "$tmp_dir/run_index.jsonl" <<'JSON'
{"timestamp":"2026-02-24T10:00:00+0000","timestamp_epoch":1761290400,"overall":"OK","exit_code":0,"logfile":"/var/log/health/full_health_monitor_latest.log","summary_file":"/var/log/health/full_health_monitor_summary_latest.log","summary_json":"/var/log/health/full_health_monitor_summary_latest.json","hosts":{"ok":10,"warn":0,"crit":0,"unknown":0,"skipped":0},"top_reasons":[{"reason":"missing_dependency","count":2}]}
{"timestamp":"2026-02-24T11:00:00+0000","timestamp_epoch":1761294000,"overall":"WARN","exit_code":1,"logfile":null,"summary_file":null,"summary_json":null,"hosts":{"ok":9,"warn":1,"crit":0,"unknown":0,"skipped":0},"top_reasons":[]}
JSON

schema="$ROOT_DIR/docs/schemas/run_index.json"
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  printf '%s' "$line" | python3 "$ROOT_DIR/tools/json_schema_validate.py" "$schema"
done < "$tmp_dir/run_index.jsonl"

echo "run_index schema ok"
