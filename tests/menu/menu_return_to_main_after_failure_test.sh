#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

source "$LM" >/dev/null 2>&1

TUI_BACKEND="whiptail"
LM_TUI_FORCE_INTERACTIVE=1
TUI_RETURN_TO_MAIN=0
TUI_LAST_CMD_RC=0

tui_textbox() { return 0; }
tui_action_result_card() { return 0; }
tui_command_confirm_if_needed() { return 0; }
tui_preview_cmd() { return 0; }
tui_post_action_choice() { printf 'main'; }

if ! tui_run_cmd "failing command" bash -lc 'exit 3'; then
  echo "interactive tui_run_cmd should not propagate failing rc when returning to main" >&2
  exit 1
fi

[[ "${TUI_LAST_CMD_RC:-}" == "3" ]] || {
  echo "expected TUI_LAST_CMD_RC=3, got '${TUI_LAST_CMD_RC:-}'" >&2
  exit 1
}
[[ "${TUI_RETURN_TO_MAIN:-0}" == "1" ]] || {
  echo "expected TUI_RETURN_TO_MAIN=1 after selecting main" >&2
  exit 1
}

echo "menu return-to-main after failure ok"
