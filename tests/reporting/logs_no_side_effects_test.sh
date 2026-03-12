#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

logdir="$workdir/missing_logs"

set +e
LOG_DIR="$logdir" bash "$LM" logs 5 >/dev/null 2>&1
rc=$?
set -e

[[ "$rc" -eq 1 ]] || {
  echo "expected logs rc=1 for missing repo log file, got rc=$rc" >&2
  exit 1
}

if [[ -d "$logdir" ]]; then
  echo "logs should not create missing repo log dir as a side effect" >&2
  exit 1
fi

echo "logs no side effects ok"
