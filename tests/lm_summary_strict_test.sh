#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$ROOT_DIR/lib/linux_maint.sh"

run_case() {
  local expect_rc="$1"; shift
  local label="$1"; shift
  set +e
  out="$(LM_SUMMARY_STRICT=1 bash -c ". \"$LIB\"; lm_summary $*" 2>&1)"
  rc=$?
  set -e
  if [[ "$rc" -ne "$expect_rc" ]]; then
    echo "FAIL: $label rc=$rc expected=$expect_rc out=$out" >&2
    return 1
  fi
}

run_case 0 "ok status" "health_monitor" "localhost" "OK"
run_case 2 "bad status" "health_monitor" "localhost" "BAD"
run_case 2 "missing host" "health_monitor" "" "OK"

echo "lm_summary strict ok"
