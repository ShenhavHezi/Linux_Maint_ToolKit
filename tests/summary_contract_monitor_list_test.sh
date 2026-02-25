#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
mon_list="$ROOT_DIR/tests/summary_contract.monitors"
exclude_list="$ROOT_DIR/tests/summary_contract_exclude.txt"

[ -f "$mon_list" ] || { echo "Missing $mon_list" >&2; exit 1; }

list_entries() {
  awk '
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }
    { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0); print $0 }
  ' "$1"
}

excludes=()
if [ -f "$exclude_list" ]; then
  while IFS= read -r line; do
    excludes+=("$line")
  done < <(list_entries "$exclude_list")
fi

is_excluded() {
  local name="$1"
  for ex in "${excludes[@]}"; do
    if [ "$name" = "$ex" ]; then
      return 0
    fi
  done
  return 1
}

missing=()
extra=()

mapfile -t listed < <(list_entries "$mon_list" | sort)
mapfile -t files < <(find "$ROOT_DIR/monitors" -maxdepth 1 -type f -name '*.sh' -printf '%f\n' | sort)

for f in "${files[@]}"; do
  if is_excluded "$f"; then
    continue
  fi
  if ! printf '%s\n' "${listed[@]}" | grep -qx "$f"; then
    missing+=("$f")
  fi
done

for f in "${listed[@]}"; do
  if is_excluded "$f"; then
    continue
  fi
  if ! printf '%s\n' "${files[@]}" | grep -qx "$f"; then
    extra+=("$f")
  fi
done

if [ "${#missing[@]}" -gt 0 ] || [ "${#extra[@]}" -gt 0 ]; then
  if [ "${#missing[@]}" -gt 0 ]; then
    echo "Missing from summary_contract.monitors:" >&2
    printf ' - %s\n' "${missing[@]}" >&2
  fi
  if [ "${#extra[@]}" -gt 0 ]; then
    echo "Listed but not found in monitors/:" >&2
    printf ' - %s\n' "${extra[@]}" >&2
  fi
  exit 1
fi

echo "summary contract monitor list ok"
