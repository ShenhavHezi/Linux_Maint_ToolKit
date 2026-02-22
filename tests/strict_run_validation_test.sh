#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR="${TMPDIR:-/tmp}"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

mon_dir="$workdir/monitors"
mkdir -p "$mon_dir"

cat > "$mon_dir/bad_monitor.sh" <<'MON'
#!/usr/bin/env bash
# Emit a malformed status to trigger strict validation.
echo "monitor=bad_monitor host=localhost status=BAD reason=oops"
exit 0
MON
chmod +x "$mon_dir/bad_monitor.sh"

mkdir -p "$workdir/logs" "$workdir/state" "$workdir/cfg"
summary_file="$workdir/summary.log"

rc=0
LM_STRICT=1 \
LM_TEST_MODE=1 \
SCRIPTS_DIR="$mon_dir" \
LM_MONITORS="bad_monitor.sh" \
LOG_DIR="$workdir/logs" \
SUMMARY_DIR="$workdir" \
SUMMARY_FILE="$summary_file" \
LM_STATE_DIR="$workdir/state" \
LM_CFG_DIR="$workdir/cfg" \
bash "$ROOT_DIR/run_full_health_monitor.sh" >/dev/null 2>"$workdir/err.log" || rc=$?

if [[ "$rc" -ne 3 ]]; then
  echo "FAIL: expected exit code 3, got $rc" >&2
  exit 1
fi

if ! grep -q "reason=summary_invalid" "$summary_file"; then
  echo "FAIL: expected reason=summary_invalid in summary file" >&2
  exit 1
fi

echo "strict run validation ok"
