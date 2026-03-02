#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

source "$LM" >/dev/null 2>&1

CAPTURED_MSGBOX=""
CAPTURED_YESNO=""

dialog() {
  local i arg next
  for ((i=1; i<=$#; i++)); do
    arg="${!i}"
    case "$arg" in
      --msgbox)
        next=$((i+1))
        CAPTURED_MSGBOX="${!next:-}"
        ;;
      --yesno)
        next=$((i+1))
        CAPTURED_YESNO="${!next:-}"
        ;;
    esac
  done
  return 0
}

TUI_BACKEND="dialog"
tui_msgbox "Line1\\nLine2\\nLine3"
tui_yesno "Q1\\nQ2"

[[ "$CAPTURED_MSGBOX" == $'Line1\nLine2\nLine3' ]] || {
  echo "msgbox newline rendering failed" >&2
  printf 'captured=%q\n' "$CAPTURED_MSGBOX" >&2
  exit 1
}
[[ "$CAPTURED_YESNO" == $'Q1\nQ2' ]] || {
  echo "yesno newline rendering failed" >&2
  printf 'captured=%q\n' "$CAPTURED_YESNO" >&2
  exit 1
}

echo "menu newline render ok"
