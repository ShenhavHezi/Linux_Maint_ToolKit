#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

log_dir="$workdir/logs"
cache_file="$workdir/trend_cache.json"
mkdir -p "$log_dir"

f1="$log_dir/full_health_monitor_summary_9999-12-31_235959.log"
cat > "$f1" <<'S'
monitor=service_monitor host=web-1 status=WARN reason=failed_units
S

json1="$(LOG_DIR="$log_dir" LM_TREND_CACHE=1 LM_TREND_CACHE_TTL=999 LM_TREND_CACHE_FILE="$cache_file" bash "$LM" trend --last 1 --json)"
printf '%s' "$json1" | python3 -c 'import json,sys; obj=json.load(sys.stdin); assert len(obj.get("runs",[]))==1'

rm -f "$f1"

json2="$(LOG_DIR="$log_dir" LM_TREND_CACHE=1 LM_TREND_CACHE_TTL=999 LM_TREND_CACHE_FILE="$cache_file" bash "$LM" trend --last 1 --json)"
printf '%s' "$json2" | python3 -c 'import json,sys; obj=json.load(sys.stdin); assert len(obj.get("runs",[]))==1, obj'

json3="$(LOG_DIR="$log_dir" LM_TREND_CACHE=1 LM_TREND_CACHE_TTL=0 LM_TREND_CACHE_FILE="$cache_file" bash "$LM" trend --last 1 --json)"
printf '%s' "$json3" | python3 -c 'import json,sys; obj=json.load(sys.stdin); assert len(obj.get("runs",[]))==0, obj'

echo "trend cache ttl ok"
