#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

out="$("$ROOT_DIR/bin/linux-maint" doctor)"

echo "$out" | grep -q '^== Monitor gates (what may SKIP) ==' 
echo "$out" | grep -q '^== Dependencies (best-effort) ==' 
echo "$out" | grep -q '^== Next recommended actions ==' 
echo "$out" | grep -q "^SKIP gate: network_monitor -> missing/empty "

echo "ok: doctor offline hints"
