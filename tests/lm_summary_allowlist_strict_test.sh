#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$ROOT_DIR/lib/linux_maint.sh"

set +e
out="$(LM_SUMMARY_ALLOWLIST='reason,foo' LM_SUMMARY_STRICT=1 bash -c ". '$LIB'; lm_summary monitorA hostA WARN reason=ssh_unreachable foo=ok bar=secret" 2>&1)"
rc=$?
set -e

if [[ "$rc" -ne 0 ]]; then
  echo "expected rc=0, got $rc" >&2
  echo "$out" >&2
  exit 1
fi

echo "$out" | grep -q 'dropped' || {
  echo "expected allowlist drop warning" >&2
  echo "$out" >&2
  exit 1
}

echo "$out" | grep -q 'reason=ssh_unreachable' || {
  echo "expected reason to be kept" >&2
  echo "$out" >&2
  exit 1
}

echo "$out" | grep -q 'foo=ok' || {
  echo "expected foo to be kept" >&2
  echo "$out" >&2
  exit 1
}

if echo "$out" | grep -q 'bar=secret'; then
  echo "expected bar to be dropped" >&2
  echo "$out" >&2
  exit 1
fi

echo "lm_summary allowlist strict ok"
