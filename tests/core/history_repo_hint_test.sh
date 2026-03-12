#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

out="$(NO_COLOR=1 LM_STATE_DIR="$workdir" bash "$LM" history 2>&1 || true)"

printf '%s\n' "$out" | grep -q -- '- Run: linux-maint run' || {
  echo "history missing-index hint did not use repo run command" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q 'sudo linux-maint run' && {
  echo "history missing-index hint leaked installed-mode sudo guidance" >&2
  echo "$out" >&2
  exit 1
}

echo "history repo hint ok"
