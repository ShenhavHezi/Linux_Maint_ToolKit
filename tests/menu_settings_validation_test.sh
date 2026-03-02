#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

source "$LM" >/dev/null 2>&1

export LM_TUI_BACKEND="invalid"
export LM_TUI_DASH_REFRESH="9999"
export LM_TUI_DEFAULT_PROBLEMS="0"
export LM_TUI_DEFAULT_REASONS="999"
export LM_TUI_DEFAULT_STATUS_VIEW="unknown"
export LM_TUI_PREVIEW="maybe"
export LM_TUI_SHORTCUTS="abc"
export LM_TUI_COMPACT="zzz"
export LM_TUI_LOW_COLOR="zzz"
export LM_TUI_CONFIRM_RISKY="zzz"

normalize_menu_settings

[[ -z "${LM_TUI_BACKEND:-}" ]] || { echo "backend should be unset on invalid value" >&2; exit 1; }
[[ "${LM_TUI_DASH_REFRESH:-}" == "300" ]] || { echo "dash refresh clamp failed" >&2; exit 1; }
[[ "${LM_TUI_DEFAULT_PROBLEMS:-}" == "1" ]] || { echo "problems clamp failed" >&2; exit 1; }
[[ "${LM_TUI_DEFAULT_REASONS:-}" == "20" ]] || { echo "reasons clamp failed" >&2; exit 1; }
[[ "${LM_TUI_DEFAULT_STATUS_VIEW:-}" == "table" ]] || { echo "status view fallback failed" >&2; exit 1; }
[[ "${LM_TUI_PREVIEW:-}" == "1" ]] || { echo "preview fallback failed" >&2; exit 1; }
[[ "${LM_TUI_SHORTCUTS:-}" == "1" ]] || { echo "shortcuts fallback failed" >&2; exit 1; }
[[ "${LM_TUI_COMPACT:-}" == "0" ]] || { echo "compact fallback failed" >&2; exit 1; }
[[ "${LM_TUI_LOW_COLOR:-}" == "0" ]] || { echo "low-color fallback failed" >&2; exit 1; }
[[ "${LM_TUI_CONFIRM_RISKY:-}" == "1" ]] || { echo "confirm-risky fallback failed" >&2; exit 1; }

echo "menu settings validation ok"
