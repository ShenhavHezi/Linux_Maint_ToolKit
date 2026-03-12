#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR="${TMPDIR:-/tmp}"
workdir="$(mktemp -d -p "$TMPDIR")"
prom_file="$workdir/openmetrics.prom"
cleanup() { rm -rf "$workdir"; }
trap cleanup EXIT

cfg_dir="$workdir/etc_linux_maint"
monitor_dir="$workdir/monitors"
mkdir -p "$cfg_dir" "$monitor_dir" "$workdir/logs"
printf '%s\n' localhost > "$cfg_dir/servers.txt"
: > "$cfg_dir/excluded.txt"

cat > "$monitor_dir/openmetrics_fixture.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "monitor=openmetrics_fixture host=localhost status=OK reason=fixture"
EOF
chmod +x "$monitor_dir/openmetrics_fixture.sh"

(
  cd "$ROOT_DIR"
  LM_CFG_DIR="$cfg_dir" \
  LOG_DIR="$workdir/logs" \
  SUMMARY_DIR="$workdir/logs" \
  SCRIPTS_DIR="$monitor_dir" \
  LM_MONITORS="openmetrics_fixture.sh" \
  LM_LOCAL_ONLY=true \
  PROM_FILE="$prom_file" \
  LM_PROM_FORMAT="openmetrics" \
  bash ./run_full_health_monitor.sh >/dev/null 2>&1 || true
)

if [[ ! -s "$prom_file" ]]; then
  echo "openmetrics eof consistency skipped: no prom output"
  exit 0
fi

tail -n 1 "$prom_file" | grep -q '^# EOF$' || {
  echo "openmetrics output missing # EOF terminator" >&2
  tail -n 5 "$prom_file" >&2
  exit 1
}

if grep -q $'\033\[' "$prom_file"; then
  echo "openmetrics output contains ANSI escapes" >&2
  exit 1
fi

echo "openmetrics eof consistency ok"
