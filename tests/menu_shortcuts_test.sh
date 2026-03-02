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
assert_eq "$(map_menu_shortcut t main)" "tools" "main t"
assert_eq "$(map_menu_shortcut c main)" "config" "main c"
assert_eq "$(map_menu_shortcut x main)" "exit" "main x"
assert_eq "$(map_menu_shortcut b run)" "back" "run b"
assert_eq "$(map_menu_shortcut l reports)" "drilldown" "reports l"
assert_eq "$(map_menu_shortcut m tools)" "metrics_prom" "tools m"
assert_eq "$(map_menu_shortcut f help)" "faq" "help f"
assert_eq "$(map_menu_shortcut a settings)" "confirmrisk" "settings a"
assert_eq "$(map_menu_shortcut q incident)" "back" "incident q"
assert_eq "$(map_menu_shortcut x drilldown)" "explain_top" "drilldown x"
assert_eq "$(map_menu_shortcut d diagnostics)" "doctor" "diag d"
assert_eq "$(map_menu_shortcut w run)" "wizard" "run w"

LM_TUI_SHORTCUTS=0
assert_eq "$(map_menu_shortcut r main)" "r" "disabled shortcuts passthrough"

echo "menu shortcuts ok"
