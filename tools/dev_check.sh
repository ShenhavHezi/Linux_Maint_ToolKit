#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

echo "==> shellcheck"
mapfile -t test_shells < <(find tests -type f -name '*.sh' | sort)
mapfile -t tool_shells < <(find tools -type f -name '*.sh' | sort)
./tools/shellcheck_wrapper.sh \
  -x run_full_health_monitor.sh \
  lib/linux_maint.sh \
  bin/linux-maint \
  monitors/*.sh \
  "${test_shells[@]}" \
  "${tool_shells[@]}"

echo "==> docs-check"
./tools/docs_link_check.sh

echo "==> smoke"
bash ./tests/smoke.sh

echo "dev_check ok"
