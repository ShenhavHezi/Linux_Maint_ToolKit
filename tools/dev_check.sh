#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

echo "==> shellcheck"
./tools/shellcheck_wrapper.sh \
  -x run_full_health_monitor.sh \
  lib/linux_maint.sh \
  bin/linux-maint \
  monitors/*.sh \
  tests/*.sh \
  tools/*.sh

echo "==> smoke"
bash ./tests/smoke.sh

echo "dev_check ok"
