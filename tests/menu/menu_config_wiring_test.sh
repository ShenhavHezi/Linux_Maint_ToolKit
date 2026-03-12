#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

source "$LM" >/dev/null 2>&1

declare -a RUN_CMDS=()
MENU_QUEUE_FILE="$(mktemp)"
cleanup() { rm -f "$MENU_QUEUE_FILE"; }
trap cleanup EXIT

tui_menu_prompt_safe() {
  local next
  if ! IFS= read -r next < "$MENU_QUEUE_FILE"; then
    TUI_MENU_RC=1
    printf ''
    return 0
  fi
  tail -n +2 "$MENU_QUEUE_FILE" > "${MENU_QUEUE_FILE}.tmp"
  mv -f "${MENU_QUEUE_FILE}.tmp" "$MENU_QUEUE_FILE"
  if [[ "$next" == "__CANCEL__" ]]; then
    TUI_MENU_RC=1
    printf ''
    return 0
  fi
  TUI_MENU_RC=0
  printf '%s' "$next"
  return 0
}

tui_run_cmd() {
  RUN_CMDS+=("$*")
  return 0
}

cat > "$MENU_QUEUE_FILE" <<'EOF'
  config   : Show config
  monitors : List monitors
back
EOF
run_menu_config

[[ "${#RUN_CMDS[@]}" -eq 2 ]] || {
  echo "unexpected number of menu actions: ${#RUN_CMDS[@]}" >&2
  printf '%s\n' "${RUN_CMDS[@]}" >&2
  exit 1
}
printf '%s\n' "${RUN_CMDS[0]}" | grep -q "linux-maint config" || {
  echo "config menu did not route to config command" >&2
  printf '%s\n' "${RUN_CMDS[@]}" >&2
  exit 1
}
printf '%s\n' "${RUN_CMDS[1]}" | grep -q "linux-maint list-monitors" || {
  echo "config menu did not route to list-monitors command" >&2
  printf '%s\n' "${RUN_CMDS[@]}" >&2
  exit 1
}

echo "menu config wiring ok"
