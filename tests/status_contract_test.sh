#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

# Use repo-mode CLI directly
LM="$ROOT_DIR/bin/linux-maint"

# 1) Non-root installed-mode status should error once (no spam)
# Skip if running as root.
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
# Force installed mode by making wrapper point to a non-repo path
# and setting MODE=installed is done by wrapper path compare.
# We simulate by running the installed binary if present.
if command -v /usr/local/bin/linux-maint >/dev/null 2>&1; then
  err=$(/usr/local/bin/linux-maint status 2>&1 >/dev/null || true)
  count=$(printf "%s\n" "$err" | grep -c "requires root" || true)
  if [ "$count" -ne 1 ]; then
    echo "Expected exactly 1 root error line, got $count" >&2
    printf "%s\n" "$err" >&2
    exit 1
  fi
fi
fi

# 2) Repo-mode status output should include totals and problems header (when run as root)
# We'll ensure we have fresh artifacts
sudo -n true >/dev/null 2>&1 || { echo "sudo without password required for this test" >&2; exit 0; }

sudo bash "$ROOT_DIR/run_full_health_monitor.sh" >/dev/null 2>&1 || true
out=$(sudo bash "$LM" status)

echo "$out" | grep -q "^totals: " || { echo "Missing totals line" >&2; echo "$out"; exit 1; }
# problems header should exist (either problems: or problems: none)
echo "$out" | grep -q "^problems" || { echo "Missing problems header" >&2; echo "$out"; exit 1; }

echo "status contract ok"
