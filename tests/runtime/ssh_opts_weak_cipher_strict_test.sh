#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

weak_opts='-o Ciphers=3des-cbc'

set +e
out="$(LM_STRICT=1 bash "$LM" run --dry-run --ssh-opts "$weak_opts" 2>&1)"
rc=$?
set -e

if [[ "$rc" -ne 2 ]]; then
  echo "expected rc=2 for weak ciphers in strict mode, got rc=$rc" >&2
  echo "$out" >&2
  exit 1
fi
printf '%s\n' "$out" | grep -qi 'weak ciphers' || {
  echo "missing weak-cipher error for strict mode" >&2
  echo "$out" >&2
  exit 1
}

out_relaxed="$(bash "$LM" run --dry-run --ssh-opts "$weak_opts" 2>&1 || true)"
printf '%s\n' "$out_relaxed" | grep -q '^Resolved hosts' || {
  echo "expected relaxed run to continue for weak ciphers" >&2
  echo "$out_relaxed" >&2
  exit 1
}

echo "ssh opts weak cipher strict test ok"
