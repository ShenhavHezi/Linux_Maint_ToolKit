#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

export LINUX_MAINT_LIB="$ROOT_DIR/lib/linux_maint.sh"
export LM_EMAIL_ENABLED=false
export LM_LOCKDIR=/tmp
export LM_LOCAL_ONLY=true

TARGETS=/tmp/network_targets_test.csv
cat > "$TARGETS" <<'CSV'
localhost,http,https://example.com,timeout=1
CSV

# Simulate missing curl by forcing lm_require_cmd to fail for curl.
export LM_FORCE_MISSING_DEPS=curl

out=$(TARGETS="$TARGETS" LM_LOGFILE=/tmp/network_monitor_missing_curl.log bash "$ROOT_DIR/monitors/network_monitor.sh" 2>&1 || true)

echo "$out" | grep -q 'reason=missing_dependency' || { echo "Expected reason=missing_dependency" >&2; echo "$out" >&2; exit 1; }
echo "$out" | grep -q 'dep=curl' || { echo "Expected dep=curl" >&2; echo "$out" >&2; exit 1; }

echo "network monitor missing curl ok"
