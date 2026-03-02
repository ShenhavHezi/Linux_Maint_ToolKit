#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Guard should not fail on current bash.
bash -c "source \"$ROOT_DIR/lib/linux_maint.sh\" >/dev/null 2>&1"

# Force a higher min version to validate the guard.
next_min=$((BASH_VERSINFO[0] + 1))
set +e
out="$(LM_MIN_BASH_OVERRIDE="$next_min" bash -c "source \"$ROOT_DIR/lib/linux_maint.sh\"" 2>&1)"
rc=$?
set -e

if [[ "$rc" -ne 2 ]]; then
  echo "expected rc=2 for min bash override, got rc=$rc" >&2
  echo "$out" >&2
  exit 1
fi
printf '%s\n' "$out" | grep -q 'requires bash' || {
  echo "expected bash version guard error" >&2
  echo "$out" >&2
  exit 1
}

echo "bash min version guard ok"
