#!/usr/bin/env bash
set -euo pipefail

# Test: per-monitor timeout overrides are honored by the wrapper.
# Use a purpose-built slow monitor to keep behavior deterministic across distros.

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}" )/.." && pwd)"

# CI/base images should provide timeout (coreutils), but keep test resilient.
if ! command -v timeout >/dev/null 2>&1; then
  echo "SKIP: timeout command is not available" >&2
  exit 0
fi

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

export LM_CFG_DIR="$workdir/etc_linux_maint"
mkdir -p "$LM_CFG_DIR"

printf '%s\n' localhost > "$LM_CFG_DIR/servers.txt"
: > "$LM_CFG_DIR/excluded.txt"

# Create a dedicated monitor script that reliably runs longer than 1 second.
mkdir -p "$workdir/monitors"
cat > "$workdir/monitors/slow_timeout_fixture.sh" <<'MON'
#!/usr/bin/env bash
set -euo pipefail
sleep 3
echo "monitor=slow_timeout_fixture host=localhost status=OK node=$(hostname -f 2>/dev/null || hostname)"
MON
chmod +x "$workdir/monitors/slow_timeout_fixture.sh"

cat > "$LM_CFG_DIR/monitor_timeouts.conf" <<'CONF'
slow_timeout_fixture=1
CONF

export SCRIPTS_DIR="$workdir/monitors"
export LM_MONITORS="slow_timeout_fixture.sh"
export LOG_DIR="$workdir/logs"
export SUMMARY_DIR="$workdir/logs"

set +e
"$REPO_DIR/run_full_health_monitor.sh" >/dev/null 2>&1
set -e

summary="$workdir/logs/full_health_monitor_summary_latest.log"
if [[ ! -f "$summary" ]]; then
  echo "Expected summary file to exist: $summary" >&2
  echo "--- logs ---" >&2
  find "$workdir/logs" -maxdepth 1 -type f -print >&2 || true
  exit 1
fi
if ! grep -q "monitor=slow_timeout_fixture .*status=UNKNOWN .*reason=timeout" "$summary"; then
  echo "Expected slow_timeout_fixture to have reason=timeout in summary." >&2
  echo "--- summary ---" >&2
  cat "$summary" >&2 || true
  exit 1
fi

if ! grep -q "monitor=slow_timeout_fixture .*timeout_secs=1" "$summary"; then
  echo "Expected slow_timeout_fixture timeout summary to include timeout_secs=1." >&2
  echo "--- summary ---" >&2
  cat "$summary" >&2 || true
  exit 1
fi

echo "per-monitor timeout override ok"
