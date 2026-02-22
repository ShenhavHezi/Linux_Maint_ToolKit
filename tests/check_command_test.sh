#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

out="$(bash "$LM" check 2>&1 || true)"
printf '%s\n' "$out" | grep -q '^=== config_validate ===' || {
  echo "check config_validate header missing" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -Eq '^config_validate: (OK|WARN|CRIT|UNKNOWN)$' || {
  echo "check config_validate status line missing" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q '^=== preflight ===' || {
  echo "check preflight header missing" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -Eq '^preflight: (OK|WARN|CRIT|UNKNOWN)$' || {
  echo "check preflight status line missing" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q '^Expected SKIPs' || {
  echo "check expected skips section missing" >&2
  echo "$out" >&2
  exit 1
}

echo "check command ok"
