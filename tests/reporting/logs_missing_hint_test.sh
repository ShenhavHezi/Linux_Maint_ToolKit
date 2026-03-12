#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

logdir="$workdir/logs"
mkdir -p "$logdir"

set +e
out="$(LOG_DIR="$logdir" bash "$LM" logs 2>&1)"
rc=$?
set -e

if [[ "$rc" -ne 1 ]]; then
  echo "expected logs rc=1 without latest log, got $rc" >&2
  echo "$out" >&2
  exit 1
fi

printf '%s\n' "$out" | grep -q '^No repo log yet: ' || {
  echo "logs missing not-found message" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q '^Hint: run linux-maint run to generate a wrapper log$' || {
  echo "logs missing hint" >&2
  echo "$out" >&2
  exit 1
}

echo "logs missing hint ok"
