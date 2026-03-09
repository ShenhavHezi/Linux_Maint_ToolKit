#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

out="$(bash "$LM" help menu 2>&1 || true)"

printf '%s\n' "$out" | grep -q '^Repo vs installed:$' || {
  echo "help menu missing repo-vs-installed section" >&2
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
printf '%s\n' "$out" | grep -q '^Key flags:$' || {
  echo "help menu missing key flags section" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q 'Main sections:' || {
  echo "help menu missing main section overview" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q 'Quickstart    first setup, current incident, and escalation workflows' || {
  echo "help menu missing quickstart summary" >&2
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
printf '%s\n' "$out" | grep -q 'Best path by task:' || {
  echo "help menu missing best path section" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q 'First day with the tool?      Quickstart -> first setup' || {
  echo "help menu missing quickstart path guidance" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q 'Need to recover quickly?       Repair -> incident or doctor' || {
  echo "help menu missing recovery path guidance" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q 'Global gum controls:' || {
  echo "help menu missing gum controls section" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q '/             command palette / action search' || {
  echo "help menu missing command palette guidance" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q 'LM_TUI_CONFIRM_RISKY=1|0' || {
  echo "help menu missing env var guidance" >&2
  echo "$out" >&2
  exit 1
}

echo "help menu structure ok"
