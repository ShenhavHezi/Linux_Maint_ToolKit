#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

source "$LM" >/dev/null 2>&1

assert_eq() {
  local got="$1" want="$2" msg="$3"
  if [[ "$got" != "$want" ]]; then
    echo "menu shortcut resolve failed: $msg (got='$got' want='$want')" >&2
    exit 1
  fi
}

assert_no_match() {
  local msg="$1"
  shift
  if resolve_menu_shortcut_tag "$@" >/dev/null 2>&1; then
    echo "menu shortcut resolve failed: $msg (unexpected match)" >&2
    exit 1
  fi
}

assert_eq "$(resolve_menu_shortcut_tag r run plan)" "run" "single match picks tag"
assert_eq "$(resolve_menu_shortcut_tag S run status)" "status" "case-insensitive"
assert_no_match "ambiguous first letter returns no match" t tools trend
assert_no_match "missing first letter returns no match" z run reports

echo "menu shortcut resolve ok"
