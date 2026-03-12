#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

if ! command -v make >/dev/null 2>&1; then
  echo "release-audit make target skipped (make not installed)"
  exit 0
fi

make -C "$ROOT_DIR" release-audit >/dev/null

echo "release-audit make target ok"
