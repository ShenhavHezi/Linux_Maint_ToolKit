#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

source "$LM" >/dev/null 2>&1

tmp_root="$(mktemp -d)"
MENU_QUEUE_FILE="$(mktemp)"
cleanup() {
  rm -rf "$tmp_root"
  rm -f "$MENU_QUEUE_FILE"
}
trap cleanup EXIT

MODE=repo
LM_CFG_DIR="$tmp_root/cfg"
LOG_DIR="$tmp_root/logs"
LM_STATE_DIR="$tmp_root/state"
mkdir -p "$LM_CFG_DIR" "$LOG_DIR" "$LM_STATE_DIR"

RUNS=()
VIEWS=()
TEXTS=()

tui_menu_prompt_safe() {
  local next
  if ! IFS= read -r next < "$MENU_QUEUE_FILE"; then
    TUI_MENU_RC=1
    printf ''
    return 0
  fi
  tail -n +2 "$MENU_QUEUE_FILE" > "${MENU_QUEUE_FILE}.tmp"
  mv -f "${MENU_QUEUE_FILE}.tmp" "$MENU_QUEUE_FILE"
  TUI_MENU_RC=0
  printf '%s' "$next"
  return 0
}

tui_edit_file() {
  RUNS+=("edit|$1|$2")
}

tui_textbox_text() {
  TEXTS+=("textbox|$1")
}

tui_view_file() {
  VIEWS+=("$1|$2")
}

cat > "$MENU_QUEUE_FILE" <<'EOF'
s
g
d
quickref
EOF

run_menu_quickstart

[[ "${RUNS[0]:-}" == *"|servers.txt inventory|"* ]] || {
  echo "quickstart inventory shortcut did not open editor" >&2
  printf 'runs=%s\n' "${RUNS[*]}" >&2
  exit 1
}
[[ "${TEXTS[0]:-}" == "textbox|hosts.d groups" ]] || {
  echo "quickstart groups shortcut did not open hosts.d overview" >&2
  printf 'texts=%s\n' "${TEXTS[*]}" >&2
  exit 1
}
[[ "${VIEWS[0]:-}" == Quick\ reference\|* ]] || {
  echo "quickstart docs shortcut did not open quick reference" >&2
  printf 'views=%s\n' "${VIEWS[*]}" >&2
  exit 1
}

echo "menu quickstart shortcuts ok"
