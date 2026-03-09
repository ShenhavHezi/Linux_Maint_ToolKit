#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

source "$LM" >/dev/null 2>&1

RUN_COUNT=0
QUICKSTART_COUNT=0
OVERVIEW_COUNT=0
INVESTIGATE_COUNT=0
REPAIR_COUNT=0
EXPORT_COUNT=0
DOCS_COUNT=0
EXIT_COUNT=0

dispatch_main_choice() {
  local choice="$1"
  choice="$(normalize_menu_choice "$choice")"
  choice="$(map_menu_shortcut "$choice" "main")"
  case "$choice" in
    quickstart) QUICKSTART_COUNT=$((QUICKSTART_COUNT+1)) ;;
    overview) OVERVIEW_COUNT=$((OVERVIEW_COUNT+1)) ;;
    run) RUN_COUNT=$((RUN_COUNT+1)) ;;
    investigate) INVESTIGATE_COUNT=$((INVESTIGATE_COUNT+1)) ;;
    repair) REPAIR_COUNT=$((REPAIR_COUNT+1)) ;;
    export) EXPORT_COUNT=$((EXPORT_COUNT+1)) ;;
    docs) DOCS_COUNT=$((DOCS_COUNT+1)) ;;
    exit) EXIT_COUNT=$((EXIT_COUNT+1)) ;;
  esac
}

LM_TUI_SHORTCUTS=1
for key in q o r i p e h x; do
  dispatch_main_choice "$key"
done

[[ "$QUICKSTART_COUNT" -eq 1 ]] || { echo "quickstart shortcut dispatch failed" >&2; exit 1; }
[[ "$OVERVIEW_COUNT" -eq 1 ]] || { echo "overview shortcut dispatch failed" >&2; exit 1; }
[[ "$RUN_COUNT" -eq 1 ]] || { echo "run shortcut dispatch failed" >&2; exit 1; }
[[ "$INVESTIGATE_COUNT" -eq 1 ]] || { echo "investigate shortcut dispatch failed" >&2; exit 1; }
[[ "$REPAIR_COUNT" -eq 1 ]] || { echo "repair shortcut dispatch failed" >&2; exit 1; }
[[ "$EXPORT_COUNT" -eq 1 ]] || { echo "export shortcut dispatch failed" >&2; exit 1; }
[[ "$DOCS_COUNT" -eq 1 ]] || { echo "docs shortcut dispatch failed" >&2; exit 1; }
[[ "$EXIT_COUNT" -eq 1 ]] || { echo "exit shortcut dispatch failed" >&2; exit 1; }

echo "menu main shortcut dispatch ok"
