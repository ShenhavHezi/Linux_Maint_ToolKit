#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$ROOT_DIR/lib/linux_maint.sh"

set +e
out="$(LM_SSH_ALLOWLIST='^nope$' LM_SSH_ALLOWLIST_STRICT=1 bash -c ". '$LIB'; lm_ssh localhost echo ok" 2>&1)"
rc=$?
set -e

if [[ "$rc" -ne 2 ]]; then
  echo "expected rc=2, got $rc" >&2
  echo "$out" >&2
  exit 1
fi

echo "lm_ssh allowlist strict ok"
