#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

assert_missing_value() {
  local label="$1"
  local expected="$2"
  shift 2

  local out rc
  set +e
  out="$(bash "$LM" "$@" 2>&1)"
  rc=$?
  set -e

  if [[ "$rc" -ne 2 ]]; then
    echo "$label: expected rc=2, got rc=$rc" >&2
    echo "$out" >&2
    exit 1
  fi

  printf '%s\n' "$out" | grep -q "^ERROR: $expected requires a value$" || {
    echo "$label: unexpected output" >&2
    echo "$out" >&2
    exit 1
  }
}

assert_missing_value "plugin search missing index" "--index" plugin search --index
assert_missing_value "plugin init missing out" "--out" plugin init demo --out
assert_missing_value "serve missing port" "--port" serve --port
assert_missing_value "agent missing interval" "--interval" agent --interval
assert_missing_value "gate missing policy" "--policy" gate --policy
assert_missing_value "policy eval missing policy" "--policy" policy eval --policy
assert_missing_value "federate missing input" "--input" federate --input
assert_missing_value "predict missing last" "--last" predict --last

echo "advanced missing flag value handling ok"
