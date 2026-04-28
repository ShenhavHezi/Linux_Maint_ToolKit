#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

python3 - "$LM" <<'PY'
import json
import subprocess
import sys
import time

lm = sys.argv[1]
cmd = [
    lm,
    "run",
    "--simulate-hosts",
    "1000",
    "--plan",
    "--json",
    "--only",
    "health_monitor",
]

start = time.monotonic()
proc = subprocess.run(cmd, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=10)
elapsed = time.monotonic() - start

if proc.returncode != 0:
    raise SystemExit(f"plan failed rc={proc.returncode}\nstderr={proc.stderr}")
if elapsed > 5:
    raise SystemExit(f"simulated 1k-host plan exceeded runtime budget: {elapsed:.3f}s")

plan = json.loads(proc.stdout)
hosts = plan.get("hosts", [])
assert plan["simulated"] is True, plan
assert plan["simulated_host_count"] == 1000, plan
assert plan["resolved_host_count"] == 1000, plan
assert len(hosts) == 1000, len(hosts)
assert hosts[0] == "sim-host-000001", hosts[:3]
assert hosts[-1] == "sim-host-001000", hosts[-3:]
assert len(set(hosts)) == 1000
assert plan["monitors"] == ["health_monitor.sh"], plan["monitors"]
PY

set +e
out="$(bash "$LM" run --simulate-hosts 10 --only health_monitor 2>&1)"
rc=$?
set -e
if [[ "$rc" -ne 2 ]]; then
  echo "expected --simulate-hosts without --plan to fail rc=2, got rc=$rc" >&2
  echo "$out" >&2
  exit 1
fi
printf '%s\n' "$out" | grep -q '^ERROR: --simulate-hosts is only supported with --plan/--dry-run$' || {
  echo "unexpected --simulate-hosts non-plan error" >&2
  echo "$out" >&2
  exit 1
}

echo "run plan simulate hosts ok"
