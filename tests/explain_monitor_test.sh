#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

out="$(bash "$LM" explain monitor health_monitor)"
printf '%s\n' "$out" | grep -q '^monitor=health_monitor'
printf '%s\n' "$out" | grep -q '^required_deps='
printf '%s\n' "$out" | grep -q '^optional_deps='
printf '%s\n' "$out" | grep -q '^common_reasons='
printf '%s\n' "$out" | grep -q 'docs/REASONS.md'

bad_out="$(bash "$LM" explain monitor not_a_monitor 2>&1 || true)"
printf '%s\n' "$bad_out" | grep -q 'Unknown monitor'

echo "ok: explain monitor"
