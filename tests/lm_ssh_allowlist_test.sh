#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$ROOT_DIR/lib/linux_maint.sh"

set +e
LM_SSH_ALLOWLIST='^echo ok$' bash -c ". \"$LIB\"; lm_ssh_allowed_cmd 'echo ok'"
rc1=$?
LM_SSH_ALLOWLIST='^echo ok$' bash -c ". \"$LIB\"; lm_ssh_allowed_cmd 'uname -a'"
rc2=$?
set -e

if [[ "$rc1" -ne 0 || "$rc2" -eq 0 ]]; then
  echo "FAIL: allowlist behavior unexpected (rc1=$rc1 rc2=$rc2)" >&2
  exit 1
fi

echo "lm_ssh allowlist ok"
