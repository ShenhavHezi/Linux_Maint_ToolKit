#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT_DIR/.logs"
SUMMARY_FILE="$LOG_DIR/full_health_monitor_summary_latest.log"

mkdir -p "$LOG_DIR"

backup=""
if [[ -f "$SUMMARY_FILE" ]]; then
  backup="$SUMMARY_FILE.bak.$$"
  cp -f "$SUMMARY_FILE" "$backup"
fi

cleanup() {
  if [[ -n "$backup" && -f "$backup" ]]; then
    mv -f "$backup" "$SUMMARY_FILE"
  else
    rm -f "$SUMMARY_FILE"
  fi
}
trap cleanup EXIT

cat > "$SUMMARY_FILE" <<'SUM'
monitor=svc host=alpha status=CRIT reason=service_failed
monitor=svc host=beta status=WARN reason=service_failed
monitor=svc host=gamma status=UNKNOWN reason=ssh_unreachable
monitor=svc host=delta status=OK
monitor=svc host=epsilon status=OK
SUM

out_full="$("$ROOT_DIR"/bin/linux-maint status --compact --group-by host --no-color)"
python3 - <<'PY' "$out_full"
import sys
out = sys.argv[1].splitlines()
rows = []
in_groups = False
for line in out:
    if line.strip() == "groups:":
        in_groups = True
        continue
    if line.startswith("problems"):
        in_groups = False
    if in_groups and line.strip():
        rows.append(line)
order = [line.split()[0] for line in rows]
expected = ["alpha", "beta", "gamma", "delta", "epsilon"]
assert order == expected, f"unexpected full order: {order}"
print("status group-by top full ok")
PY

out_top="$("$ROOT_DIR"/bin/linux-maint status --compact --group-by host --top 3 --no-color)"
python3 - <<'PY' "$out_top"
import sys
out = sys.argv[1].splitlines()
rows = []
in_groups = False
for line in out:
    if line.strip() == "groups:":
        in_groups = True
        continue
    if line.startswith("problems"):
        in_groups = False
    if in_groups and line.strip():
        rows.append(line)
order = [line.split()[0] for line in rows]
expected = ["alpha", "beta", "gamma"]
assert order == expected, f"unexpected top order: {order}"
print("status group-by top capped ok")
PY
