#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

mon_dir="$workdir/monitors"
mkdir -p "$mon_dir"

cat > "$mon_dir/fast.sh" <<'MON'
#!/usr/bin/env bash
set -euo pipefail
host=$(hostname -f 2>/dev/null || hostname)
echo "monitor=fast host=$host status=OK msg=ok"
MON

cat > "$mon_dir/slow.sh" <<'MON'
#!/usr/bin/env bash
set -euo pipefail
sleep 1
host=$(hostname -f 2>/dev/null || hostname)
echo "monitor=slow host=$host status=OK msg=ok"
MON

chmod +x "$mon_dir/fast.sh" "$mon_dir/slow.sh"

logdir="$workdir/logs"
mkdir -p "$logdir"

LM_MONITORS="fast.sh slow.sh" \
  SCRIPTS_DIR="$mon_dir" \
  LOG_DIR="$logdir" \
  SUMMARY_DIR="$logdir" \
  LM_STATE_DIR="$workdir/state" \
  TMPDIR="$workdir/tmp" \
  bash "$ROOT_DIR/run_full_health_monitor.sh" >/dev/null 2>&1

logfile="$(find "$logdir" -maxdepth 1 -type f -name 'full_health_monitor_[0-9][0-9][0-9][0-9]-*.log' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n 1 | awk '{print $2}')"

if ! grep -a -q 'RUNTIME monitor=fast ms=' "$logfile"; then
  echo "missing runtime line for fast" >&2
  tail -n 200 "$logfile" >&2 || true
  exit 1
fi
if ! grep -a -q 'RUNTIME monitor=slow ms=' "$logfile"; then
  echo "missing runtime line for slow" >&2
  tail -n 200 "$logfile" >&2 || true
  exit 1
fi
if ! grep -a -q 'Top runtimes' "$logfile"; then
  echo "missing Top runtimes section" >&2
  tail -n 200 "$logfile" >&2 || true
  exit 1
fi

echo "ok: wrapper runtime summary"
