#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

out="$(bash "$LM" explain reason config_missing)"

printf '%s\n' "$out" | grep -q -- '- Run: linux-maint init' || {
  echo "config_missing explain did not use repo init hint" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q 'sudo linux-maint init' && {
  echo "config_missing explain leaked installed-mode sudo guidance" >&2
  echo "$out" >&2
  exit 1
}

echo "explain config_missing repo ok"
