#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$ROOT_DIR/lib/linux_maint.sh"

out1="$(bash -c ". '$LIB'; lm_summary network_monitor host1 UNKNOWN reason=ssh_unreachable")"

echo "$out1" | grep -q 'next_step=check_ssh' || {
  echo "missing next_step for ssh_unreachable" >&2
  echo "$out1" >&2
  exit 1
}

out2="$(bash -c ". '$LIB'; lm_summary preflight_check host1 UNKNOWN reason=missing_dependency dep=curl")"

echo "$out2" | grep -q 'next_step=install_dependency' || {
  echo "missing next_step for missing_dependency" >&2
  echo "$out2" >&2
  exit 1
}

out3="$(bash -c ". '$LIB'; lm_summary timer_monitor host1 SKIP reason=timer_missing")"

echo "$out3" | grep -q 'next_step=enable_timer' || {
  echo "missing next_step for timer_missing" >&2
  echo "$out3" >&2
  exit 1
}

echo "next_step hints ok"
