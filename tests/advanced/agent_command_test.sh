#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

out="$(bash "$LM" agent --once --dry-run 2>/dev/null || true)"
printf '%s\n' "$out" | grep -q "agent dry-run iteration=1" || {
  echo "agent --once --dry-run output mismatch" >&2
  echo "$out" >&2
  exit 1
}

echo "agent command ok"
