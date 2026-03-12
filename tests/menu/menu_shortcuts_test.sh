#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
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
assert_eq "$(map_menu_shortcut q main)" "quickstart" "main q"
assert_eq "$(map_menu_shortcut o main)" "overview" "main o"
assert_eq "$(map_menu_shortcut r main)" "run" "main r"
assert_eq "$(map_menu_shortcut t main)" "triage" "main t"
assert_eq "$(map_menu_shortcut s main)" "share" "main s"
assert_eq "$(map_menu_shortcut i main)" "triage" "main i legacy"
assert_eq "$(map_menu_shortcut p main)" "triage" "main p legacy"
assert_eq "$(map_menu_shortcut e main)" "share" "main e legacy"
assert_eq "$(map_menu_shortcut h main)" "share" "main h legacy"
assert_eq "$(map_menu_shortcut d main)" "triage" "main d legacy"
assert_eq "$(map_menu_shortcut c main)" "share" "main c legacy"
assert_eq "$(map_menu_shortcut x main)" "exit" "main x"
assert_eq "$(map_menu_shortcut b run)" "back" "run b"
assert_eq "$(map_menu_shortcut d overview)" "dashboard" "overview d"
assert_eq "$(map_menu_shortcut d investigate)" "drilldown" "investigate d"
assert_eq "$(map_menu_shortcut d repair)" "doctor" "repair d"
assert_eq "$(map_menu_shortcut m export)" "metrics_prom" "export m"
assert_eq "$(map_menu_shortcut d triage)" "drilldown" "triage d"
assert_eq "$(map_menu_shortcut x triage)" "diff" "triage x"
assert_eq "$(map_menu_shortcut o triage)" "doctor" "triage o"
assert_eq "$(map_menu_shortcut h triage)" "history" "triage h"
assert_eq "$(map_menu_shortcut e share)" "export_json" "share e"
assert_eq "$(map_menu_shortcut h share)" "quickref" "share h"
assert_eq "$(map_menu_shortcut g share)" "troubleshooting" "share g"
assert_eq "$(map_menu_shortcut s share)" "settings" "share s"
assert_eq "$(map_menu_shortcut f docs)" "faq" "docs f"
assert_eq "$(map_menu_shortcut t docs)" "troubleshooting" "docs t"
assert_eq "$(map_menu_shortcut e docs)" "explain_reason" "docs e"
assert_eq "$(map_menu_shortcut a settings)" "confirmrisk" "settings a"
assert_eq "$(map_menu_shortcut q incident)" "back" "incident q"
assert_eq "$(map_menu_shortcut c incident)" "recommended" "incident c"
assert_eq "$(map_menu_shortcut x drilldown)" "explain_top" "drilldown x"
assert_eq "$(map_menu_shortcut w run)" "wizard" "run w"
assert_eq "$(map_menu_shortcut f quickstart)" "first_setup" "quickstart f"
assert_eq "$(map_menu_shortcut i quickstart)" "current_incident" "quickstart i"
assert_eq "$(map_menu_shortcut e quickstart)" "escalation" "quickstart e"
assert_eq "$(map_menu_shortcut s quickstart)" "inventory" "quickstart s"
assert_eq "$(map_menu_shortcut g quickstart)" "groups" "quickstart g"
assert_eq "$(map_menu_shortcut d quickstart)" "docs" "quickstart d"

LM_TUI_SHORTCUTS=0
assert_eq "$(map_menu_shortcut r main)" "r" "disabled shortcuts passthrough"

echo "menu shortcuts ok"
