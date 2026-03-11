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
mkdir -p "$LOG_DIR" "$LM_STATE_DIR"

overview_preview="$(tui_section_preview_body overview "")"
[[ "$overview_preview" == *"Recommended first action: first_setup"* ]] || {
  echo "overview empty state should recommend first_setup" >&2
  echo "$overview_preview" >&2
  exit 1
}
[[ "$overview_preview" == *"No current summary yet"* ]] || {
  echo "overview empty state should mention missing summary" >&2
  echo "$overview_preview" >&2
  exit 1
}

investigate_preview="$(tui_section_preview_body investigate "")"
[[ "$investigate_preview" == *"Investigate needs either a summary, a log, or history artifacts"* ]] || {
  echo "investigate empty state missing artifact guidance" >&2
  echo "$investigate_preview" >&2
  exit 1
}
[[ "$investigate_preview" == *"summary=no  logs=no  history=no"* ]] || {
  echo "investigate empty state missing readiness indicators" >&2
  echo "$investigate_preview" >&2
  exit 1
}

next_steps="$(tui_bootstrap_next_steps_lines)"
[[ "$next_steps" == *"Use Quickstart -> first setup"* ]] || {
  echo "bootstrap next steps should point to first setup" >&2
  echo "$next_steps" >&2
  exit 1
}

echo "menu empty state preview ok"
