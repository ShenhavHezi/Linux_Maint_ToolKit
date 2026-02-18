#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$ROOT_DIR/lib/linux_maint.sh"

out="$(bash -c ". \"$LIB\"; lm_time test_monitor step1 true")"
echo "$out" | grep -q '^RUNTIME_STEP monitor=test_monitor step=step1 ms=[0-9]\+ rc=0$'

set +e
out2="$(bash -c ". \"$LIB\"; lm_time test_monitor step2 false")"
rc=$?
set -e
[[ "$rc" -ne 0 ]]
echo "$out2" | grep -q '^RUNTIME_STEP monitor=test_monitor step=step2 ms=[0-9]\+ rc=1$'

echo "lm_time ok"
