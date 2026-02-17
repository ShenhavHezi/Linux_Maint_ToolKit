#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

# Known reason token should resolve from REASONS.md
out="$(bash "$LM" explain reason ssh_unreachable)"
echo "$out" | grep -q 'ssh_unreachable'

# Unknown reason token should fail clearly.
set +e
bad_out="$(bash "$LM" explain reason this_token_does_not_exist 2>&1)"
rc=$?
set -e
if [[ "$rc" -ne 1 ]]; then
  echo "expected rc=1 for unknown reason token, got rc=$rc" >&2
  exit 1
fi
echo "$bad_out" | grep -q 'Unknown reason token'

# Status explain contract
for st in OK WARN CRIT UNKNOWN SKIP; do
  s_out="$(bash "$LM" explain status "$st")"
  echo "$s_out" | grep -q "^$st:"
done

echo "ok: explain reason"
