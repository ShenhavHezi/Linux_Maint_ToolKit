#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

check_sections() {
  local cmd="$1"
  local out
  out="$(bash "$LM" help "$cmd" 2>&1 || true)"
  printf '%s\n' "$out" | grep -q '^Purpose:$' || {
    echo "help $cmd missing Purpose section" >&2
    echo "$out" >&2
    exit 1
  }
  printf '%s\n' "$out" | grep -q '^When to use:$' || {
    echo "help $cmd missing When to use section" >&2
    echo "$out" >&2
    exit 1
  }
  printf '%s\n' "$out" | grep -q '^Examples:$' || {
    echo "help $cmd missing Examples section" >&2
    echo "$out" >&2
    exit 1
  }
}

check_sections run
check_sections menu
check_sections status
check_sections report
check_sections config
check_sections doctor
check_sections check
check_sections history
check_sections trend
check_sections export
check_sections pack-logs
check_sections verify-install
check_sections self-check
check_sections security-profile
check_sections metrics
check_sections notify
check_sections ticket
check_sections audit-log
check_sections cm-hook
check_sections serve
check_sections agent
check_sections policy
check_sections federate
check_sections ai-assist
check_sections predict
check_sections diff
check_sections logs
check_sections explain

echo "help command consistency ok"
