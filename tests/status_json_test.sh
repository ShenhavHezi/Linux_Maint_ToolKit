#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

if ! sudo -n true >/dev/null 2>&1; then
  echo "sudo without password required for this test" >&2
  exit 0
fi

sudo bash "$ROOT_DIR/run_full_health_monitor.sh" >/dev/null 2>&1 || true

# Pipe JSON to python for validation
# (Use -c instead of a heredoc so stdin remains the pipe; avoids ShellCheck SC2259.)
sudo bash "$LM" status --json | \
  python3 -c 'import json,sys; obj=json.load(sys.stdin); assert "mode" in obj; assert "last_status" in obj; assert "totals" in obj; assert "problems" in obj; assert isinstance(obj["problems"], list); assert "runtime_warnings" in obj; assert isinstance(obj["runtime_warnings"], list); [obj["totals"][k] for k in ["CRIT","WARN","UNKNOWN","SKIP","OK"]]; print("status --json ok")'
