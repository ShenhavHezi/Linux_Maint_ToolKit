#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

# quick-check should be runnable without shellcheck and should execute contract/lint checks.
if ! command -v make >/dev/null 2>&1; then
  echo "quick-check make target skipped (make not installed)"
  exit 0
fi

make -C "$ROOT_DIR" quick-check >/dev/null

echo "quick-check make target ok"
