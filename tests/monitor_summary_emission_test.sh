#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

export LINUX_MAINT_LIB="$ROOT_DIR/lib/linux_maint.sh"
export PATH="$ROOT_DIR/lib:$PATH"
export LM_EMAIL_ENABLED=false
export LM_LOCKDIR=/tmp
export LM_LOG_DIR=/tmp
export LM_LOGFILE=/tmp/linux_maint_test.log
export LM_STATE_DIR=/tmp/linux_maint_state
export LM_LOCAL_ONLY=true
export LM_INVENTORY_OUTPUT_DIR="/tmp/linux_maint_inventory"
# Some monitors need a writable config dir for baselines/allowlists when running unprivileged in CI.
export LM_CFG_DIR="${LM_CFG_DIR:-/tmp/linux_maint_cfg}"

mkdir -p "$LM_INVENTORY_OUTPUT_DIR" "$LM_STATE_DIR" "$LM_CFG_DIR"

fail=0

for m in "$ROOT_DIR"/monitors/*.sh; do
  name="$(basename "$m" .sh)"
  out_file="/tmp/${name}_summary_test.out"

  # Ensure each monitor uses a writable logfile (avoid /var/log permission issues in CI)
  LM_LOGFILE="/tmp/${name}_summary_test.log" \
  LM_LOG_DIR=/tmp \
  LM_STATE_DIR="$LM_STATE_DIR" \
  LM_CFG_DIR="$LM_CFG_DIR" \
  bash "$m" >"$out_file" 2>/dev/null || true

  if ! grep -q '^monitor=' "$out_file"; then
    echo "FAIL: $name emitted no monitor= summary line" >&2
    echo "--- output (first 50 lines) ---" >&2
    head -n 50 "$out_file" >&2 || true
    echo "--- end output ---" >&2
    fail=1
  fi

done

[ "$fail" -eq 0 ]

echo "monitor summary emission ok"
