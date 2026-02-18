#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

mon_dir="$workdir/monitors"
mkdir -p "$mon_dir"

cat > "$mon_dir/slow_monitor.sh" <<'MON'
#!/usr/bin/env bash
set -euo pipefail
sleep 5
MON
chmod +x "$mon_dir/slow_monitor.sh"

set +e
out="$({ \
  SUMMARY_CONTRACT_MONITORS_DIR="$mon_dir" \
  SUMMARY_CONTRACT_MONITORS="slow_monitor.sh" \
  SUMMARY_CONTRACT_MONITOR_TIMEOUT_SECS=1 \
  bash "$ROOT_DIR/tests/summary_contract.sh"; \
} 2>&1)"
rc=$?
set -e

if [[ "$rc" -eq 0 ]]; then
  echo "expected non-zero rc for timeout-guard failure" >&2
  echo "$out" >&2
  exit 1
fi

echo "$out" | grep -q '^TIMEOUT: slow_monitor.sh exceeded 1s$'

echo "summary contract timeout guard ok"
