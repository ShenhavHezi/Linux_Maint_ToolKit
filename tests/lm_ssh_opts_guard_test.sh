#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$ROOT_DIR/lib/linux_maint.sh"

bad='-o BatchMode=yes;id'
set +e
out="$(LM_SSH_OPTS="$bad" bash -c ". \"$LIB\"; lm_ssh localhost \"echo ok\" " 2>&1)"
rc=$?
set -e

if [[ "$rc" -ne 2 ]]; then
  echo "expected rc=2 for unsafe LM_SSH_OPTS, got rc=$rc" >&2
  echo "$out" >&2
  exit 1
fi

printf '%s\n' "$out" | grep -q 'ERROR: unsafe characters detected in LM_SSH_OPTS' || {
  echo "missing unsafe-options error" >&2
  echo "$out" >&2
  exit 1
}

echo "lm_ssh opts guard ok"
