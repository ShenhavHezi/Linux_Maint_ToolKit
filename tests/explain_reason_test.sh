#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

out="$("$ROOT_DIR/bin/linux-maint" explain reason ssh_unreachable)"

echo "$out" | grep -q 'ssh_unreachable'

echo "ok: explain reason"
