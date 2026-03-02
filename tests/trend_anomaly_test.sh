#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"
LOG_DIR="$(mktemp -d)"
trap 'rm -rf "$LOG_DIR"' EXIT

# Build 6 synthetic runs: baseline CRIT=0 for 5 runs, then spike to CRIT=6.
for i in 1 2 3 4 5; do
  ts="$(printf '9999-12-2%d_12000%d' "$i" "$i")"
  cat > "$LOG_DIR/full_health_monitor_summary_${ts}.log" <<'S'
monitor=service_monitor host=web status=OK
monitor=network_monitor host=web status=OK
S
done
cat > "$LOG_DIR/full_health_monitor_summary_9999-12-30_120006.log" <<'S'
monitor=service_monitor host=web status=CRIT reason=failed_units
monitor=network_monitor host=web status=CRIT reason=http_down
monitor=disk_trend_monitor host=web status=CRIT reason=disk_growth
monitor=nfs_mount_monitor host=web status=CRIT reason=nfs_unreachable
monitor=patch_monitor host=web status=CRIT reason=security_updates_pending
monitor=health_monitor host=web status=CRIT reason=high_load
S

json_out="$(LOG_DIR="$LOG_DIR" bash "$LM" trend --last 6 --json --anomaly --anomaly-window 5 --anomaly-z 2.0)"
JSON_OUT="$json_out" python3 - <<'PY'
import json, os
o = json.loads(os.environ["JSON_OUT"])
an = o.get("anomaly") or {}
assert an.get("enabled") is True
assert an.get("enough_data") is True
signals = an.get("signals") or []
crit = next((s for s in signals if s.get("metric") == "CRIT"), None)
assert crit is not None
assert crit.get("anomalous") is True
assert float(crit.get("zscore", 0)) >= 2.0
PY

human_out="$(NO_COLOR=1 LOG_DIR="$LOG_DIR" bash "$LM" trend --last 6 --anomaly --anomaly-window 5 --anomaly-z 2.0)"
printf '%s\n' "$human_out" | grep -q '^anomaly_signals:' || {
  echo "missing anomaly_signals section in human trend output" >&2
  echo "$human_out" >&2
  exit 1
}
printf '%s\n' "$human_out" | grep -q '^CRIT: current=' || {
  echo "expected CRIT anomaly line in human output" >&2
  echo "$human_out" >&2
  exit 1
}

echo "trend anomaly ok"
