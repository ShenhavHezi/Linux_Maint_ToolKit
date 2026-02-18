#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

mon_dir="$workdir/monitors"
mkdir -p "$mon_dir"

cat > "$mon_dir/slow.sh" <<'MON'
#!/usr/bin/env bash
set -euo pipefail
sleep 1
host=$(hostname -f 2>/dev/null || hostname)
echo "monitor=slow host=$host status=OK msg=ok"
MON
chmod +x "$mon_dir/slow.sh"

cfg="$workdir/etc_linux_maint"
mkdir -p "$cfg"
cat > "$cfg/monitor_runtime_warn.conf" <<'CONF'
slow=1
CONF

logdir="$workdir/logs"
mkdir -p "$logdir"

set +e
LM_MONITORS="slow.sh" \
  SCRIPTS_DIR="$mon_dir" \
  LOG_DIR="$logdir" \
  SUMMARY_DIR="$logdir" \
  LM_STATE_DIR="$workdir/state" \
  LM_CFG_DIR="$cfg" \
  TMPDIR="$workdir/tmp" \
  bash "$ROOT_DIR/run_full_health_monitor.sh" >/dev/null 2>&1
rc=$?
set -e

if [[ "$rc" -ne 1 ]]; then
  echo "expected wrapper rc=1 for runtime warning, got $rc" >&2
  exit 1
fi

logfile="$(find "$logdir" -maxdepth 1 -type f -name 'full_health_monitor_[0-9][0-9][0-9][0-9]-*.log' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n 1 | awk '{print $2}')"

if ! grep -a -q 'monitor=runtime_guard .*reason=runtime_exceeded .*target_monitor=slow' "$logfile"; then
  echo "missing runtime_guard warning" >&2
  tail -n 200 "$logfile" >&2 || true
  exit 1
fi

echo "ok: runtime warn threshold"
