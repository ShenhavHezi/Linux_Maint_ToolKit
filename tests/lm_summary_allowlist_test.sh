#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$ROOT_DIR/lib/linux_maint.sh"

out="$(LM_SUMMARY_ALLOWLIST='reason,foo' bash -c ". \"$LIB\"; lm_summary monitorA hostA OK reason=ok token=secret foo=bar baretoken")"

echo "$out" | grep -q 'reason=ok'
echo "$out" | grep -q 'foo=bar'
if echo "$out" | grep -q 'token=secret'; then
  echo "FAIL: allowlist did not drop token" >&2
  exit 1
fi
if echo "$out" | grep -q 'baretoken'; then
  echo "FAIL: allowlist did not drop bare token" >&2
  exit 1
fi

echo "lm_summary allowlist ok"
