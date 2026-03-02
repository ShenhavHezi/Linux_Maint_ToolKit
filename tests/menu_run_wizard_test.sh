#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

source "$LM" >/dev/null 2>&1

declare -a RUN_CMDS=()
MENU_QUEUE_FILE="$(mktemp)"
INPUT_QUEUE_FILE="$(mktemp)"
cleanup() { rm -f "$MENU_QUEUE_FILE" "$INPUT_QUEUE_FILE"; }
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

tui_input() {
  local next
  if ! IFS= read -r next < "$INPUT_QUEUE_FILE"; then
    TUI_INPUT_RC=1
    printf ''
    return 0
  fi
  tail -n +2 "$INPUT_QUEUE_FILE" > "${INPUT_QUEUE_FILE}.tmp"
  mv -f "${INPUT_QUEUE_FILE}.tmp" "$INPUT_QUEUE_FILE"
  TUI_INPUT_RC=0
  printf '%s' "$next"
  return 0
}

tui_run_cmd() {
  RUN_CMDS+=("$*")
  return 0
}

tui_run_live() {
  RUN_CMDS+=("LIVE $*")
  return 0
}

tui_run_next_steps() { return 0; }

# Plan flow
cat > "$MENU_QUEUE_FILE" <<'EOF'
only
hosts
plan
EOF
cat > "$INPUT_QUEUE_FILE" <<'EOF'
service_monitor,ntp_drift_monitor
server-a,server-b
EOF
tui_run_wizard

[[ "${#RUN_CMDS[@]}" -eq 1 ]] || { echo "expected one wizard command" >&2; exit 1; }
printf '%s\n' "${RUN_CMDS[0]}" | grep -q "linux-maint run --plan (wizard)" || {
  echo "wizard did not execute plan path" >&2
  printf '%s\n' "${RUN_CMDS[@]}" >&2
  exit 1
}
printf '%s\n' "${RUN_CMDS[0]}" | grep -q -- "--only service_monitor,ntp_drift_monitor" || {
  echo "wizard plan missing --only" >&2
  printf '%s\n' "${RUN_CMDS[@]}" >&2
  exit 1
}
printf '%s\n' "${RUN_CMDS[0]}" | grep -q -- "--hosts server-a,server-b" || {
  echo "wizard plan missing --hosts" >&2
  printf '%s\n' "${RUN_CMDS[@]}" >&2
  exit 1
}

# Cancel flow should not execute anything
RUN_CMDS=()
cat > "$MENU_QUEUE_FILE" <<'EOF'
back
EOF
: > "$INPUT_QUEUE_FILE"
tui_run_wizard
[[ "${#RUN_CMDS[@]}" -eq 0 ]] || {
  echo "cancel flow should not run commands" >&2
  printf '%s\n' "${RUN_CMDS[@]}" >&2
  exit 1
}

echo "menu run wizard ok"
