#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

export LINUX_MAINT_LIB="$ROOT_DIR/lib/linux_maint.sh"
export LM_EMAIL_ENABLED=false
export LM_LOCKDIR=/tmp
export LM_LOGFILE=/tmp/linux_maint_monitor_exit_codes_test.log
export LM_LOCAL_ONLY=true

allowed_re='^(0|1|2|3)$'

fail=0

for m in "$ROOT_DIR"/monitors/*.sh; do
  name="$(basename "$m")"
  # Each monitor should be runnable in isolation with safe env.
  # If it cannot determine status due to perms/deps, it should return 3.
  LM_LOGFILE="/tmp/${name%.sh}.log" bash "$m" >/dev/null 2>&1 || rc=$?
  rc=${rc:-0}

  if ! [[ "$rc" =~ $allowed_re ]]; then
    echo "FAIL: $name returned rc=$rc (expected 0/1/2/3)" >&2
    fail=1
  fi

  unset rc

done

[ "$fail" -eq 0 ]

echo "monitor exit codes ok"
