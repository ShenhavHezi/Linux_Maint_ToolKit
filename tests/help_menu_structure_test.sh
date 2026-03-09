#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

out="$(bash "$LM" help menu 2>&1 || true)"

printf '%s\n' "$out" | grep -q '^Mode:$' || {
  echo "help menu missing Mode section" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q 'repo mode:      linux-maint menu' || {
  echo "help menu missing repo-mode guidance" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q 'installed mode: sudo linux-maint menu' || {
  echo "help menu missing installed-mode guidance" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q '^Main sections:$' || {
  echo "help menu missing main section overview" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q 'Diagnostics   doctor, logs, self-check, security profile, incident mode' || {
  echo "help menu missing diagnostics summary" >&2
  echo "$out" >&2
  exit 1
}

echo "help menu structure ok"
