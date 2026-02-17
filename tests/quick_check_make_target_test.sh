#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

# quick-check should be runnable without shellcheck and should execute contract/lint checks.
make -C "$ROOT_DIR" quick-check >/dev/null

echo "quick-check make target ok"
