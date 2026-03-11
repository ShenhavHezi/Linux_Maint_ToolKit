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
SUMMARY_DIR="$tmp_root/logs"
LM_STATE_DIR="$tmp_root/state"
mkdir -p "$LM_CFG_DIR" "$LOG_DIR" "$LM_STATE_DIR"

RUNS=()
VIEWS=()
MSGS=()

tui_msgbox() {
  MSGS+=("$1")
}

tui_menu_prompt_safe() {
  TUI_MENU_RC=0
  case "$1" in
    "First setup: config bootstrap") printf 'minimal' ;;
    "First setup: next guide") printf 'baselines' ;;
    "Starter baselines") printf 'all' ;;
    *) printf 'finish' ;;
  esac
}

tui_yesno() {
  case "$1" in
    *"Open the quick reference"*) return 0 ;;
    *"Run readiness checks now"*) return 0 ;;
    *"Preview the first run plan now"*) return 0 ;;
    *) return 1 ;;
  esac
}

tui_run_cmd() {
  RUNS+=("$*")
}

tui_view_file() {
  VIEWS+=("$1|$2")
}

expected_skips_text() {
  return 1
}

tui_quickstart_first_setup

joined_runs="$(printf '%s\n' "${RUNS[@]}")"
grep -q '^linux-maint init --minimal .* init --minimal$' <<< "$joined_runs" || {
  echo "wizard should run minimal init first" >&2
  printf '%s\n' "$joined_runs" >&2
  exit 1
}
grep -q '^linux-maint check .* check$' <<< "$joined_runs" || {
  echo "wizard should run check" >&2
  printf '%s\n' "$joined_runs" >&2
  exit 1
}
grep -q '^linux-maint run --plan .* run --plan$' <<< "$joined_runs" || {
  echo "wizard should run plan preview" >&2
  printf '%s\n' "$joined_runs" >&2
  exit 1
}
for target in ports configs users sudoers; do
  grep -q "^linux-maint baseline $target --update --local-only .* baseline $target --update --local-only$" <<< "$joined_runs" || {
    echo "wizard missing baseline capture for $target" >&2
    printf '%s\n' "$joined_runs" >&2
    exit 1
  }
done

[[ "${#VIEWS[@]}" -eq 1 ]] || {
  echo "wizard should open quick reference once" >&2
  printf 'views=%s\n' "${VIEWS[*]}" >&2
  exit 1
}
[[ "${MSGS[0]:-}" == *"First setup assistant"* ]] || {
  echo "wizard should start with assistant intro" >&2
  printf 'msgs=%s\n' "${MSGS[*]}" >&2
  exit 1
}
last_msg="${MSGS[$((${#MSGS[@]} - 1))]:-}"
[[ "$last_msg" == *"Bootstrap complete."* ]] || {
  echo "wizard should finish with completion summary" >&2
  printf 'msgs=%s\n' "${MSGS[*]}" >&2
  exit 1
}

echo "menu first setup wizard ok"
