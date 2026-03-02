#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

source "$LM" >/dev/null 2>&1

assert_eq() {
  local got="$1" want="$2" msg="$3"
  [[ "$got" == "$want" ]] || {
    echo "shortcut mapping failed: $msg (got='$got' want='$want')" >&2
    exit 1
  }
}

LM_TUI_SHORTCUTS=1
assert_eq "$(map_menu_shortcut r main)" "run" "main r"
assert_eq "$(map_menu_shortcut s main)" "reports" "main s"
assert_eq "$(map_menu_shortcut d diagnostics)" "doctor" "diag d"
assert_eq "$(map_menu_shortcut w run)" "wizard" "run w"

LM_TUI_SHORTCUTS=0
assert_eq "$(map_menu_shortcut r main)" "r" "disabled shortcuts passthrough"

echo "menu shortcuts ok"
