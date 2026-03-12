#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"
TMPDIR="${TMPDIR:-/tmp}"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

log_dir="$workdir/logs"
mkdir -p "$log_dir"

# Build 100k monitor summary lines across timestamped summary files.
python3 - "$log_dir" <<'PY'
import os, sys
log_dir = sys.argv[1]
files = 250
lines_per_file = 400  # 250 * 400 = 100,000 lines
for i in range(files):
    day = 1 + (i // 10)
    sec = i % 60
    ts = f"9999-01-{day:02d}_{120000+sec:06d}"
    p = os.path.join(log_dir, f"full_health_monitor_summary_{ts}.log")
    with open(p, "w", encoding="utf-8") as f:
        for j in range(lines_per_file):
            st = "OK"
            reason = ""
            if j % 97 == 0:
                st = "WARN"
                reason = " reason=security_updates_pending"
            elif j % 211 == 0:
                st = "CRIT"
                reason = " reason=service_inactive"
            f.write(f"monitor=health_monitor host=h{j%25:02d} status={st}{reason}\n")
PY

start="$(date +%s)"
json_out="$(LOG_DIR="$log_dir" bash "$LM" trend --last 250 --json 2>/dev/null || true)"
end="$(date +%s)"
elapsed=$((end - start))

JSON_OUT="$json_out" python3 - <<'PY'
import json, os
o = json.loads(os.environ["JSON_OUT"])
runs = o.get("runs") or []
assert len(runs) == 250
tot = o.get("totals") or {}
assert int(tot.get("OK", 0)) > 0
assert int(tot.get("WARN", 0)) > 0
assert int(tot.get("CRIT", 0)) > 0
PY

# Keep threshold permissive for CI variance while ensuring bounded runtime.
[[ "$elapsed" -le 25 ]] || {
  echo "trend large-fixture perf regression: ${elapsed}s (>25s)" >&2
  exit 1
}

echo "trend large fixture perf ok (${elapsed}s)"
