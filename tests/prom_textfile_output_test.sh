#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PROM_FILE="${PROM_FILE:-/var/lib/node_exporter/textfile_collector/linux_maint.prom}"

# Best-effort: run wrapper in repo mode without sudo (may emit many UNKNOWN/SKIP; that's fine).
# We only validate the Prometheus exposition format is sane.
(
  cd "$ROOT_DIR"
  bash ./run_full_health_monitor.sh >/dev/null 2>&1 || true
)

if [ ! -s "$PROM_FILE" ]; then
  echo "MISSING or EMPTY prom file: $PROM_FILE" >&2
  exit 1
fi

req_metrics=(
  "linux_maint_overall_status"
  "linux_maint_summary_hosts_count"
  "linux_maint_monitor_status_count"
  "linux_maint_monitor_status"
)

for m in "${req_metrics[@]}"; do
  if ! grep -q "^${m}" "$PROM_FILE"; then
    echo "MISSING metric in prom output: $m" >&2
    exit 1
  fi
done

# Ensure linux_maint_monitor_status doesn't contain duplicate labelsets (Prometheus rejects that).
python3 - <<'PY'
import re
from collections import Counter
p = '/var/lib/node_exporter/textfile_collector/linux_maint.prom'
text=open(p,'r',errors='ignore').read().splitlines()
pat=re.compile(r'^linux_maint_monitor_status\{([^}]*)\}\s')
seen=Counter()
for line in text:
    m=pat.match(line)
    if not m:
        continue
    seen[m.group(1)]+=1

dups=[(k,v) for k,v in seen.items() if v>1]
if dups:
    raise SystemExit(f"duplicate linux_maint_monitor_status labelsets found: {dups[:5]}")
print('prom textfile ok')
PY
