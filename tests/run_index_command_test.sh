#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

index_file="$workdir/run_index.jsonl"
cat > "$index_file" <<'JSON'
{"run_index_version":1,"timestamp":"2026-02-24T10:00:00+0000","timestamp_epoch":1761290400,"overall":"OK","exit_code":0,"logfile":"/var/log/health/full_health_monitor_latest.log","summary_file":"/var/log/health/full_health_monitor_summary_latest.log","summary_json":"/var/log/health/full_health_monitor_summary_latest.json","hosts":{"ok":10,"warn":0,"crit":0,"unknown":0,"skipped":0},"top_reasons":[{"reason":"missing_dependency","count":2}]}
{"run_index_version":1,"timestamp":"2026-02-24T11:00:00+0000","timestamp_epoch":1761294000,"overall":"WARN","exit_code":1,"logfile":null,"summary_file":null,"summary_json":null,"hosts":{"ok":9,"warn":1,"crit":0,"unknown":0,"skipped":0},"top_reasons":[]}
{"run_index_version":1,"timestamp":"2026-02-24T12:00:00+0000","timestamp_epoch":1761297600,"overall":"CRIT","exit_code":2,"logfile":null,"summary_file":null,"summary_json":null,"hosts":{"ok":8,"warn":1,"crit":1,"unknown":0,"skipped":0},"top_reasons":[{"reason":"ssh_unreachable","count":1}]}
JSON

export LM_RUN_INDEX_FILE="$index_file"

stats_json="$(bash "$LM" run-index --stats --json)"
printf '%s' "$stats_json" | python3 -c 'import json,sys; o=json.load(sys.stdin); assert o["count"]==3; assert o["last"]["overall"]=="CRIT"; assert o["last"]["exit_code"]==2'

prune_json="$(bash "$LM" run-index --prune --keep 2 --json)"
printf '%s' "$prune_json" | python3 -c 'import json,sys; o=json.load(sys.stdin); assert o["kept"]==2; assert o["total_before"]==3'

lines=$(wc -l < "$index_file" | tr -d ' ')
if [[ "$lines" -ne 2 ]]; then
  echo "expected 2 lines after prune, got $lines" >&2
  exit 1
fi

echo "run-index command ok"
