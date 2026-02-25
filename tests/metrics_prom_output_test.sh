#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

out="$(bash "$LM" metrics --prom 2>/dev/null || true)"
if [ -z "$out" ]; then
  echo "metrics --prom produced empty output" >&2
  exit 1
fi
if ! printf '%s\n' "$out" | grep -q '^linux_maint_overall_status'; then
  echo "metrics --prom missing linux_maint_overall_status" >&2
  exit 1
fi
if ! printf '%s\n' "$out" | grep -q '^linux_maint_last_run_exit_code'; then
  echo "metrics --prom missing linux_maint_last_run_exit_code" >&2
  exit 1
fi
if ! printf '%s\n' "$out" | grep -q '^linux_maint_last_run_timestamp'; then
  echo "metrics --prom missing linux_maint_last_run_timestamp" >&2
  exit 1
fi

echo "metrics --prom ok"
