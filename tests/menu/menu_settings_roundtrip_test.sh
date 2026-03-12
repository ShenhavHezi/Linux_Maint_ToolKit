#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

tmp_home="$(mktemp -d)"
cleanup() { rm -rf "$tmp_home"; }
trap cleanup EXIT

HOME="$tmp_home"
XDG_CONFIG_HOME="$tmp_home/.config"
export HOME XDG_CONFIG_HOME

source "$LM" >/dev/null 2>&1

export LM_TUI_BACKEND="dialog"
export LM_TUI_DASH_REFRESH="9"
export LM_TUI_DEFAULT_STATUS_VIEW="compact"
export LM_TUI_DEFAULT_PROBLEMS="33"
export LM_TUI_DEFAULT_REASONS="7"
export LM_TUI_PREVIEW="0"
export LM_TUI_SHORTCUTS="0"
export LM_TUI_COMPACT="1"
export LM_TUI_LOW_COLOR="1"
export LM_TUI_CONFIRM_RISKY="0"

save_menu_settings

unset LM_TUI_BACKEND LM_TUI_DASH_REFRESH LM_TUI_DEFAULT_STATUS_VIEW LM_TUI_DEFAULT_PROBLEMS LM_TUI_DEFAULT_REASONS LM_TUI_PREVIEW LM_TUI_SHORTCUTS LM_TUI_COMPACT LM_TUI_LOW_COLOR LM_TUI_CONFIRM_RISKY
load_menu_settings

[[ "${LM_TUI_BACKEND:-}" == "dialog" ]] || { echo "backend mismatch" >&2; exit 1; }
[[ "${LM_TUI_DASH_REFRESH:-}" == "9" ]] || { echo "refresh mismatch" >&2; exit 1; }
[[ "${LM_TUI_DEFAULT_STATUS_VIEW:-}" == "compact" ]] || { echo "view mismatch" >&2; exit 1; }
[[ "${LM_TUI_DEFAULT_PROBLEMS:-}" == "33" ]] || { echo "problems mismatch" >&2; exit 1; }
[[ "${LM_TUI_DEFAULT_REASONS:-}" == "7" ]] || { echo "reasons mismatch" >&2; exit 1; }
[[ "${LM_TUI_PREVIEW:-}" == "0" ]] || { echo "preview mismatch" >&2; exit 1; }
[[ "${LM_TUI_SHORTCUTS:-}" == "0" ]] || { echo "shortcuts mismatch" >&2; exit 1; }
[[ "${LM_TUI_COMPACT:-}" == "1" ]] || { echo "compact mismatch" >&2; exit 1; }
[[ "${LM_TUI_LOW_COLOR:-}" == "1" ]] || { echo "low color mismatch" >&2; exit 1; }
[[ "${LM_TUI_CONFIRM_RISKY:-}" == "0" ]] || { echo "confirm risky mismatch" >&2; exit 1; }

echo "menu settings roundtrip ok"
