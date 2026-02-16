#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

# Target should be idempotent: two consecutive runs should succeed.
make -C "$ROOT_DIR" install-githooks >/dev/null
make -C "$ROOT_DIR" install-githooks >/dev/null

for hook in pre-commit pre-push; do
  path="$ROOT_DIR/.git/hooks/$hook"
  [[ -x "$path" ]] || { echo "missing expected hook: $path" >&2; exit 1; }
done

echo "install-githooks make target ok"
