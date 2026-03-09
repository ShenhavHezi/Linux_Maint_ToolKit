#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

out="$(bash "$LM" help 2>&1 || true)"

printf '%s\n' "$out" | grep -q '^Most-used operator paths:$' || {
  echo "top-level help missing operator paths section" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q '^Investigate / export:$' || {
  echo "top-level help missing investigate/export section" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -F -q 'Automation / integrations:' || {
  echo "top-level help missing automation section" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q '^Menu sections:$' || {
  echo "top-level help missing menu sections section" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q '^Examples by task:$' || {
  echo "top-level help missing examples-by-task section" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q '^Best next commands:$' || {
  echo "top-level help missing best-next-commands section" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q '^  menu[[:space:]]\+Interactive operations console (Overview / Run / Investigate / Repair / Export / Docs)$' || {
  echo "top-level help missing polished menu description" >&2
  echo "$out" >&2
  exit 1
}

echo "help top-level structure ok"
