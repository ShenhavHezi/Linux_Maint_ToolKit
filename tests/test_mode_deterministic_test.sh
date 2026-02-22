#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR="${TMPDIR:-/tmp}"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

mon_dir="$workdir/monitors"
mkdir -p "$mon_dir"

cat > "$mon_dir/ok_monitor.sh" <<'MON'
#!/usr/bin/env bash
echo "monitor=ok_monitor host=localhost status=OK"
exit 0
MON
chmod +x "$mon_dir/ok_monitor.sh"

mkdir -p "$workdir/logs" "$workdir/state" "$workdir/cfg"

LM_TEST_MODE=1 \
SCRIPTS_DIR="$mon_dir" \
LM_MONITORS="ok_monitor.sh" \
LOG_DIR="$workdir/logs" \
SUMMARY_DIR="$workdir" \
LM_STATE_DIR="$workdir/state" \
LM_CFG_DIR="$workdir/cfg" \
bash "$ROOT_DIR/run_full_health_monitor.sh" >/dev/null 2>"$workdir/err.log"

status_file="$workdir/logs/last_status_full"
if [[ ! -f "$status_file" ]]; then
  echo "FAIL: missing last_status_full" >&2
  exit 1
fi

expected_ts="$(date -Is -d "@946684800")"
actual_ts="$(awk -F= '/^timestamp=/{print $2; exit}' "$status_file")"

if [[ "$actual_ts" != "$expected_ts" ]]; then
  echo "FAIL: deterministic timestamp mismatch" >&2
  echo "expected=$expected_ts" >&2
  echo "actual=$actual_ts" >&2
  exit 1
fi

echo "test mode deterministic ok"
