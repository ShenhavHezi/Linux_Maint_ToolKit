#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

source "$LM" >/dev/null 2>&1

# Avoid UI dependencies in test mode.
tui_textbox() { return 0; }
tui_gum_header() { return 0; }
tui_gum_hint() { return 0; }
clear() { return 0; }

infile="$(mktemp)"
out1="$(mktemp)"
out2="$(mktemp)"
cleanup() { rm -f "$infile" "$out1" "$out2"; }
trap cleanup EXIT

printf 'TOKEN_FROM_STDIN\n' > "$infile"

# tui_run_cmd should not pass caller stdin to child command.
TUI_BACKEND="whiptail"
exec 0<"$infile"
# shellcheck disable=SC2016
OUT_FILE="$out1" tui_run_cmd "stdin-guard-cmd" bash -lc 'if IFS= read -r line; then printf "%s" "$line" > "$OUT_FILE"; else printf "EOF" > "$OUT_FILE"; fi'
[[ "$(cat "$out1")" == "EOF" ]] || {
  echo "tui_run_cmd leaked stdin to child process" >&2
  cat "$out1" >&2
  exit 1
}

# gum live path should also isolate stdin.
printf 'TOKEN_FROM_STDIN\n' > "$infile"
TUI_BACKEND="gum"
exec 0<"$infile"
# shellcheck disable=SC2016
OUT_FILE="$out2" tui_run_live "stdin-guard-live" bash -lc 'if IFS= read -r line; then printf "%s" "$line" > "$OUT_FILE"; else printf "EOF" > "$OUT_FILE"; fi'
[[ "$(cat "$out2")" == "EOF" ]] || {
  echo "tui_run_live leaked stdin to child process" >&2
  cat "$out2" >&2
  exit 1
}

echo "menu stdin guard ok"
