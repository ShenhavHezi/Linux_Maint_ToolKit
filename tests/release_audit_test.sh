#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

out="$(bash "$ROOT_DIR/tools/release_audit.sh" 2>&1 || true)"
printf '%s\n' "$out" | grep -q '^release_audit: OK$' || {
  echo "release_audit did not pass" >&2
  echo "$out" >&2
  exit 1
}

echo "release_audit test ok"
