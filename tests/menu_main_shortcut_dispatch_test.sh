#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

source "$LM" >/dev/null 2>&1

RUN_COUNT=0
REPORTS_COUNT=0
TOOLS_COUNT=0
DIAG_COUNT=0
CONFIG_COUNT=0
HELP_COUNT=0
EXIT_COUNT=0

dispatch_main_choice() {
  local choice="$1"
  choice="$(normalize_menu_choice "$choice")"
  choice="$(map_menu_shortcut "$choice" "main")"
  case "$choice" in
    run) RUN_COUNT=$((RUN_COUNT+1)) ;;
    reports) REPORTS_COUNT=$((REPORTS_COUNT+1)) ;;
    tools) TOOLS_COUNT=$((TOOLS_COUNT+1)) ;;
    diagnostics) DIAG_COUNT=$((DIAG_COUNT+1)) ;;
    config) CONFIG_COUNT=$((CONFIG_COUNT+1)) ;;
    help) HELP_COUNT=$((HELP_COUNT+1)) ;;
    exit) EXIT_COUNT=$((EXIT_COUNT+1)) ;;
  esac
}

LM_TUI_SHORTCUTS=1
for key in r s t d c h x; do
  dispatch_main_choice "$key"
done

[[ "$RUN_COUNT" -eq 1 ]] || { echo "run shortcut dispatch failed" >&2; exit 1; }
[[ "$REPORTS_COUNT" -eq 1 ]] || { echo "reports shortcut dispatch failed" >&2; exit 1; }
[[ "$TOOLS_COUNT" -eq 1 ]] || { echo "tools shortcut dispatch failed" >&2; exit 1; }
[[ "$DIAG_COUNT" -eq 1 ]] || { echo "diagnostics shortcut dispatch failed" >&2; exit 1; }
[[ "$CONFIG_COUNT" -eq 1 ]] || { echo "config shortcut dispatch failed" >&2; exit 1; }
[[ "$HELP_COUNT" -eq 1 ]] || { echo "help shortcut dispatch failed" >&2; exit 1; }
[[ "$EXIT_COUNT" -eq 1 ]] || { echo "exit shortcut dispatch failed" >&2; exit 1; }

echo "menu main shortcut dispatch ok"
