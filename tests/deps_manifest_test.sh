#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

out="$(bash "$LM" deps)"

echo "$out" | grep -q '^=== linux-maint deps ===$'
echo "$out" | grep -q '^format: monitor|required|optional|available_required|available_optional$'

echo "$out" | grep -q '^monitor=network_monitor|required=awk sed grep|optional=curl|available_required='
echo "$out" | grep -q '^monitor=storage_health_monitor|required=awk sed grep|optional=smartctl nvme|available_required='

echo "deps manifest ok"
