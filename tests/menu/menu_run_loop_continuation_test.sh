#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

source "$LM" >/dev/null 2>&1

MENU_QUEUE_FILE="$(mktemp)"
cleanup() { rm -f "$MENU_QUEUE_FILE"; }
trap cleanup EXIT

LIVE_COUNT=0
PLAN_COUNT=0

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

tui_yesno() { return 0; }
tui_run_live() {
  LIVE_COUNT=$((LIVE_COUNT+1))
  # Simulate progress/noisy line from run path.
  echo "ONE 100% - summary ready (run: linux-maint report)"
  return 0
}
tui_run_next_steps() { return 0; }
tui_run_cmd() {
  case "$1" in
    "linux-maint run --plan") PLAN_COUNT=$((PLAN_COUNT+1)) ;;
  esac
  return 0
}

cat > "$MENU_QUEUE_FILE" <<'EOF'
run
plan
back
EOF

run_menu_run >/dev/null

[[ "$LIVE_COUNT" -eq 1 ]] || {
  echo "expected run action once, got $LIVE_COUNT" >&2
  exit 1
}
[[ "$PLAN_COUNT" -eq 1 ]] || {
  echo "expected plan action once after run, got $PLAN_COUNT" >&2
  exit 1
}

echo "menu run loop continuation ok"
