#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

source "$LM" >/dev/null 2>&1

MENU_QUEUE_FILE="$(mktemp)"
cleanup() { rm -f "$MENU_QUEUE_FILE"; }
trap cleanup EXIT

RUN_MENU_COUNT=0
QUICKSTART_MENU_COUNT=0
REPAIR_MENU_COUNT=0
EXIT_SEEN=0

run_menu_quickstart() { QUICKSTART_MENU_COUNT=$((QUICKSTART_MENU_COUNT+1)); }
run_menu_overview() { :; }
run_menu_run() { RUN_MENU_COUNT=$((RUN_MENU_COUNT+1)); }
run_menu_investigate() { :; }
run_menu_repair() { REPAIR_MENU_COUNT=$((REPAIR_MENU_COUNT+1)); }
run_menu_export() { :; }
run_menu_docs() { :; }

cat > "$MENU_QUEUE_FILE" <<'EOF'
q
r
p
x
EOF

while true; do
  local_choice=""
  if ! IFS= read -r local_choice < "$MENU_QUEUE_FILE"; then
    break
  fi
  tail -n +2 "$MENU_QUEUE_FILE" > "${MENU_QUEUE_FILE}.tmp"
  mv -f "${MENU_QUEUE_FILE}.tmp" "$MENU_QUEUE_FILE"
  local_choice="$(normalize_menu_choice "$local_choice")"
  local_choice="$(map_menu_shortcut "$local_choice" "main")"
  case "$local_choice" in
    quickstart) run_menu_quickstart ;;
    overview) run_menu_overview ;;
    run) run_menu_run ;;
    investigate) run_menu_investigate ;;
    repair) run_menu_repair ;;
    export) run_menu_export ;;
    docs) run_menu_docs ;;
    exit) EXIT_SEEN=1; break ;;
  esac
done

[[ "$QUICKSTART_MENU_COUNT" -eq 1 ]] || {
  echo "expected quickstart submenu once, got $QUICKSTART_MENU_COUNT" >&2
  exit 1
}
[[ "$RUN_MENU_COUNT" -eq 1 ]] || {
  echo "expected run submenu once, got $RUN_MENU_COUNT" >&2
  exit 1
}
[[ "$REPAIR_MENU_COUNT" -eq 1 ]] || {
  echo "expected repair submenu once after run, got $REPAIR_MENU_COUNT" >&2
  exit 1
}
[[ "$EXIT_SEEN" -eq 1 ]] || {
  echo "expected exit to end loop" >&2
  exit 1
}

echo "menu main loop continuation ok"
