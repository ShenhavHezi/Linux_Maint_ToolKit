#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"
EXPECTED="$ROOT_DIR/tests/fixtures/menu_help_overlay.txt"

source "$LM" >/dev/null 2>&1

LM_TUI_SHORTCUTS=1
out="$(tui_menu_help_overlay_text "Overview" "overview" $'dashboard|Open: live operations dashboard [d]\nstatus|Open: current status snapshot [s]\nback|Back to main menu [b]\n')"

if ! diff -u "$EXPECTED" <(printf '%s\n' "$out") >/dev/null; then
  echo "menu help overlay text mismatch" >&2
  diff -u "$EXPECTED" <(printf '%s\n' "$out") >&2 || true
  exit 1
fi

echo "menu help overlay text ok"
