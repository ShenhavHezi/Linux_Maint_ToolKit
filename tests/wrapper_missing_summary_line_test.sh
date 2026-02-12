#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

# Run the wrapper with a minimal monitor list containing a monitor that emits no monitor= line
# and exits non-zero. The wrapper should synthesize an UNKNOWN summary with reason=early_exit.

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

mon_dir="$workdir/monitors"
mkdir -p "$mon_dir"

cat > "$mon_dir/bad_monitor.sh" <<'MON'
#!/usr/bin/env bash
set -euo pipefail
# Intentionally emit no monitor= line
exit 2
MON
chmod +x "$mon_dir/bad_monitor.sh"

logdir="$workdir/logs"
mkdir -p "$logdir"
logfile="$logdir/full_health_monitor_test.log"

set +e
LM_MONITORS="bad_monitor.sh" SCRIPTS_DIR="$mon_dir" LOG_DIR="$logdir" SUMMARY_DIR="$logdir" bash "$ROOT_DIR/run_full_health_monitor.sh" >/dev/null 2>&1
rc=$?
set -e

if [[ "$rc" -eq 0 ]]; then
  echo "expected non-zero rc" >&2
  exit 1
fi

# The wrapper writes its tmp_report into LOG_DIR logfile; search that.
if ! grep -a -q '^monitor=bad_monitor host=runner status=UNKNOWN .*reason=early_exit' "$logdir"/full_health_monitor_*.log; then
  echo "missing synthetic summary line in wrapper log:" >&2
  tail -n 200 "$logdir"/full_health_monitor_*.log >&2 || true
  exit 1
fi

echo "ok: wrapper synthesized summary on missing monitor= line"
