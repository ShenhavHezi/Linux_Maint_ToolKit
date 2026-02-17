#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"
mkdir -p .logs

echo "==> summary_contract"
bash ./tests/summary_contract.sh

echo "==> no_eval_lint"
bash ./tests/no_eval_lint.sh

echo "quick_check ok"
