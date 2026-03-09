#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

source "$LM" >/dev/null 2>&1

tmp_root="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_root"
}
trap cleanup EXIT

MODE=repo
LM_CFG_DIR="$tmp_root/cfg"
LOG_DIR="$tmp_root/logs"
LM_STATE_DIR="$tmp_root/state"
mkdir -p "$LM_CFG_DIR" "$LOG_DIR" "$LM_STATE_DIR"
printf '%s\n' "localhost" > "$LM_CFG_DIR/servers.txt"

out="$(tui_menu_action_previews_text "Quickstart" "quickstart" $'first_setup|Guide: first setup and safe first run [f]\ninventory|Edit: servers.txt inventory [s]\ndocs|Open: setup docs [d]\nback|Back to main menu [b]\n')"
[[ "$out" == *"[first_setup] Guide: first setup and safe first run [f]"* ]] || {
  echo "action preview text missing first_setup header" >&2
  echo "$out" >&2
  exit 1
}
[[ "$out" == *"Opens your main servers inventory file in an editor."* ]] || {
  echo "action preview text missing inventory preview" >&2
  echo "$out" >&2
  exit 1
}
[[ "$out" == *"Opens key setup docs from the Quickstart path."* ]] || {
  echo "action preview text missing docs preview" >&2
  echo "$out" >&2
  exit 1
}
[[ "$out" == *"Returns to the previous menu level."* ]] || {
  echo "action preview text missing back preview" >&2
  echo "$out" >&2
  exit 1
}

echo "menu action preview text ok"
