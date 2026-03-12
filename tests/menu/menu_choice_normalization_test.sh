#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

source "$LM" >/dev/null 2>&1

assert_eq() {
  local got="$1" want="$2" msg="$3"
  if [[ "$got" != "$want" ]]; then
    echo "menu normalize failed: $msg (got='$got' want='$want')" >&2
    exit 1
  fi
}

assert_eq "$(normalize_menu_choice "  config   : Show config")" "config" "padded dialog tag"
assert_eq "$(normalize_menu_choice "reports: Status / report")" "reports" "simple label"
assert_eq "$(normalize_menu_choice $'\033[33mexit\033[0m: Exit')" "exit" "ansi-colored tag"
assert_eq "$(normalize_menu_choice "   monitors")" "monitors" "leading spaces"

echo "menu choice normalization ok"
