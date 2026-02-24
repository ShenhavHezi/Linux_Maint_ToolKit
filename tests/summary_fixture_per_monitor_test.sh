#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$ROOT_DIR/tests/fixtures/summary_all_monitors.txt"
mon_list="$ROOT_DIR/tests/summary_contract.monitors"

[ -f "$fixture" ] || { echo "Missing fixture: $fixture" >&2; exit 1; }
[ -f "$mon_list" ] || { echo "Missing monitor list: $mon_list" >&2; exit 1; }

missing=()
while IFS= read -r line; do
  case "$line" in
    ""|\#*) continue ;;
  esac
  mon="${line%.sh}"
  if ! grep -q "^monitor=${mon} " "$fixture"; then
    missing+=("$mon")
  fi
done < "$mon_list"

if [ "${#missing[@]}" -gt 0 ]; then
  echo "Fixture missing monitor lines:" >&2
  printf ' - %s\n' "${missing[@]}" >&2
  exit 1
fi

python3 "$ROOT_DIR/tests/summary_parse_safety_lint.py" "$fixture"
python3 "$ROOT_DIR/tests/summary_contract_lint.py" "$fixture"

echo "summary fixture per monitor ok"
