#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

out="$(bash "$LM" status --summary 2>&1 || true)"
printf '%s\n' "$out" | grep -q 'overall=' || {
  echo "status --summary missing overall" >&2
  echo "$out" >&2
  exit 1
}

out_table="$(bash "$LM" status --summary --table 2>&1 || true)"
printf '%s\n' "$out_table" | grep -q 'overall=' || {
  echo "status --summary --table missing summary" >&2
  echo "$out_table" >&2
  exit 1
}
printf '%s\n' "$out_table" | grep -Eq '^STATUS[[:space:]]+MONITOR' || {
  echo "status --summary --table missing table header" >&2
  echo "$out_table" >&2
  exit 1
}

color_out="$(NO_COLOR= LM_FORCE_COLOR=1 bash "$LM" status --summary --table 2>/dev/null || true)"
printf '%s\n' "$color_out" | grep -q $'\033' || {
  echo "status --table should contain ANSI when color enabled" >&2
  echo "$color_out" >&2
  exit 1
}

echo "status summary ok"

compact_out="$(bash "$LM" status --compact 2>/dev/null || true)"
printf '%s\n' "$compact_out" | grep -q '=== Mode ===' && {
  echo "status --compact should hide mode header" >&2
  echo "$compact_out" >&2
  exit 1
}

echo "status compact ok"

doctor_compact_out="$(bash "$LM" doctor --compact 2>/dev/null || true)"
printf '%s\n' "$doctor_compact_out" | grep -q '^== Files ==' && {
  echo "doctor --compact should hide Files section" >&2
  echo "$doctor_compact_out" >&2
  exit 1
}
printf '%s\n' "$doctor_compact_out" | grep -q '^note=compact' || {
  echo "doctor --compact missing compact note" >&2
  echo "$doctor_compact_out" >&2
  exit 1
}

self_compact_out="$(bash "$LM" self-check --compact 2>/dev/null || true)"
printf '%s\n' "$self_compact_out" | grep -q '^== Paths' && {
  echo "self-check --compact should hide Paths section" >&2
  echo "$self_compact_out" >&2
  exit 1
}
printf '%s\n' "$self_compact_out" | grep -q '^note=compact' || {
  echo "self-check --compact missing compact note" >&2
  echo "$self_compact_out" >&2
  exit 1
}

echo "compact doctor/self-check ok"
