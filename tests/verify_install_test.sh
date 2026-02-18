#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

out="$("$ROOT_DIR/bin/linux-maint" verify-install 2>/dev/null)"

echo "$out" | grep -q '^verify-install ok$'

echo "ok: verify-install"
