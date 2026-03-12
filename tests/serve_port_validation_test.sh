#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

set +e
out="$(bash "$LM" serve --port 70000 2>&1)"
rc=$?
set -e

[[ "$rc" -eq 2 ]] || {
  echo "expected serve invalid port failure rc=2, got rc=$rc" >&2
  echo "$out" >&2
  exit 1
}

printf '%s\n' "$out" | grep -q -- '--port must be between 1 and 65535' || {
  echo "unexpected serve invalid port output" >&2
  echo "$out" >&2
  exit 1
}

echo "serve port validation ok"
