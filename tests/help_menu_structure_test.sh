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
printf '%s\n' "$out" | grep -q 'Overview      dashboard, current state, top problems, and next moves' || {
  echo "help menu missing overview summary" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q 'Repair        guided incident response, doctor, check, self-check, and security profile' || {
  echo "help menu missing repair summary" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q '^Best path by task:$' || {
  echo "help menu missing best path section" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q 'Need to recover quickly?       Repair -> incident or doctor' || {
  echo "help menu missing recovery path guidance" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q '^Global gum controls:$' || {
  echo "help menu missing gum controls section" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q '/             command palette / action search' || {
  echo "help menu missing command palette guidance" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q '^Bundle flow:$' || {
  echo "help menu missing bundle flow section" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q 'Export -> pack_logs opens a guided bundle wizard' || {
  echo "help menu missing bundle wizard guidance" >&2
  echo "$out" >&2
  exit 1
}

echo "help menu structure ok"
