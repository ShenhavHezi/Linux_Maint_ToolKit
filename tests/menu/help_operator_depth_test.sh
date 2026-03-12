#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

config_help="$(bash "$LM" help config 2>&1 || true)"
printf '%s\n' "$config_help" | grep -q '^Purpose:$' || {
  echo "help config missing purpose section" >&2
  echo "$config_help" >&2
  exit 1
}
printf '%s\n' "$config_help" | grep -q 'Read the effective merged configuration from the active config root' || {
  echo "help config missing cfg_dir explanation" >&2
  echo "$config_help" >&2
  exit 1
}
printf '%s\n' "$config_help" | grep -q -- '--diff-defaults' || {
  echo "help config missing diff-defaults flag docs" >&2
  echo "$config_help" >&2
  exit 1
}

doctor_help="$(bash "$LM" help doctor 2>&1 || true)"
printf '%s\n' "$doctor_help" | grep -q '^Key flags:$' || {
  echo "help doctor missing key flags section" >&2
  echo "$doctor_help" >&2
  exit 1
}
printf '%s\n' "$doctor_help" | grep -q 'Fix mode:' || {
  echo "help doctor missing Fix mode section" >&2
  echo "$doctor_help" >&2
  exit 1
}
printf '%s\n' "$doctor_help" | grep -q 'In repo mode, doctor targets repo-local paths' || {
  echo "help doctor missing repo-mode note" >&2
  echo "$doctor_help" >&2
  exit 1
}

check_help="$(bash "$LM" help check 2>&1 || true)"
printf '%s\n' "$check_help" | grep -q '^Exit behavior:$' || {
  echo "help check missing exit behavior section" >&2
  echo "$check_help" >&2
  exit 1
}
printf '%s\n' "$check_help" | grep -q 'Exit code follows the highest underlying severity' || {
  echo "help check missing exit code note" >&2
  echo "$check_help" >&2
  exit 1
}

echo "help operator depth ok"
