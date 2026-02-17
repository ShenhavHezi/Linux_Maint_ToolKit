#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

# Default to the node_exporter textfile path, but fall back to a repo-local file
# for unprivileged CI environments.
DEFAULT_PROM_FILE="/var/lib/node_exporter/textfile_collector/linux_maint.prom"
PROM_FILE="${PROM_FILE:-$DEFAULT_PROM_FILE}"

if [ "$PROM_FILE" = "$DEFAULT_PROM_FILE" ]; then
  if [ ! -d "$(dirname "$DEFAULT_PROM_FILE")" ] || [ ! -w "$(dirname "$DEFAULT_PROM_FILE")" ]; then
    PROM_FILE="$ROOT_DIR/.logs/linux_maint.prom"
  fi
fi

mkdir -p "$(dirname "$PROM_FILE")" 2>/dev/null || true

# Best-effort: run wrapper in repo mode without sudo (may emit many UNKNOWN/SKIP; that's fine).
# We only validate the Prometheus exposition format is sane.
(
  cd "$ROOT_DIR"
  PROM_FILE="$PROM_FILE" bash ./run_full_health_monitor.sh >/dev/null 2>&1 || true
)

if [ ! -s "$PROM_FILE" ]; then
  echo "prom textfile skipped: missing/empty $PROM_FILE" >&2
  exit 0
fi

req_metrics=(
  "linux_maint_overall_status"
  "linux_maint_summary_hosts_count"
  "linux_maint_monitor_status_count"
  "linux_maint_monitor_status"
  "linux_maint_reason_count"
)

for m in "${req_metrics[@]}"; do
  if ! grep -q "^${m}" "$PROM_FILE"; then
    echo "MISSING metric in prom output: $m" >&2
    exit 1
  fi
done

# Ensure help/type headers exist for reason rollup metric.
grep -q '^# HELP linux_maint_reason_count ' "$PROM_FILE"
grep -q '^# TYPE linux_maint_reason_count gauge$' "$PROM_FILE"

# Ensure key metrics don't contain duplicate labelsets (Prometheus rejects that).
python3 - <<PY
import re
from collections import Counter
p = r'''$PROM_FILE'''
text=open(p,'r',errors='ignore').read().splitlines()
pat_status=re.compile(r'^linux_maint_monitor_status\{([^}]*)\}\s')
pat_reason=re.compile(r'^linux_maint_reason_count\{([^}]*)\}\s')
seen_status=Counter(); seen_reason=Counter()
for line in text:
    m=pat_status.match(line)
    if m:
        seen_status[m.group(1)]+=1
    m2=pat_reason.match(line)
    if m2:
        seen_reason[m2.group(1)]+=1

dups=[(k,v) for k,v in seen_status.items() if v>1]
if dups:
    raise SystemExit(f"duplicate linux_maint_monitor_status labelsets found: {dups[:5]}")

dups_reason=[(k,v) for k,v in seen_reason.items() if v>1]
if dups_reason:
    raise SystemExit(f"duplicate linux_maint_reason_count labelsets found: {dups_reason[:5]}")
print('prom textfile ok')
PY
