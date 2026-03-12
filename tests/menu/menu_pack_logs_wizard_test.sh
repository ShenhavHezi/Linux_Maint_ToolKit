#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

source "$LM" >/dev/null 2>&1

MODE=repo

PROMPTS=()
RUN_TITLE=""
RUN_ARGS=()
SUMMARY_DIR=""
SUMMARY_REDACT=""

tui_input_capture() {
  local prompt="$1" placeholder="${2:-}"
  PROMPTS+=("$prompt|$placeholder")
  case "$prompt" in
    "Support bundle output directory")
      TUI_INPUT_VALUE="/tmp/support-fixture"
      TUI_INPUT_RC=0
      ;;
    "GPG recipient")
      TUI_INPUT_VALUE="ops@example.com"
      TUI_INPUT_RC=0
      ;;
    *)
      TUI_INPUT_VALUE=""
      TUI_INPUT_RC=0
      ;;
  esac
}

tui_yesno() {
  local msg="$1"
  case "$msg" in
    *"Redact sensitive data"*) return 0 ;;
    *"Include a SHA256 manifest"*) return 0 ;;
    *"Encrypt the bundle with GPG"*) return 0 ;;
    *"Keep the plaintext .tar.gz"*) return 1 ;;
    *"Create support bundle with these settings?"*) return 0 ;;
    *)
      echo "unexpected yes/no prompt: $msg" >&2
      return 1
      ;;
  esac
}

tui_run_cmd() {
  RUN_TITLE="$1"
  shift || true
  RUN_ARGS=("$@")
  return 0
}

tui_support_bundle_summary() {
  SUMMARY_DIR="${1:-}"
  SUMMARY_REDACT="${2:-}"
}

tui_msgbox() {
  :
}

tui_pack_logs_wizard

[[ "$RUN_TITLE" == "linux-maint pack-logs" ]] || {
  echo "unexpected run title: $RUN_TITLE" >&2
  exit 1
}

[[ "${RUN_ARGS[1]:-}" == "pack-logs" ]] || {
  echo "wizard did not build pack-logs command" >&2
  printf 'args=%s\n' "${RUN_ARGS[*]}" >&2
  exit 1
}

args_joined="${RUN_ARGS[*]}"
[[ "$args_joined" == *"--out /tmp/support-fixture"* ]] || {
  echo "wizard missing output dir" >&2
  echo "$args_joined" >&2
  exit 1
}
[[ "$args_joined" == *"--redact"* ]] || {
  echo "wizard missing redact flag" >&2
  echo "$args_joined" >&2
  exit 1
}
[[ "$args_joined" == *"--hash"* ]] || {
  echo "wizard missing hash flag" >&2
  echo "$args_joined" >&2
  exit 1
}
[[ "$args_joined" == *"--gpg --gpg-recipient ops@example.com"* ]] || {
  echo "wizard missing gpg flags" >&2
  echo "$args_joined" >&2
  exit 1
}
[[ "$args_joined" != *"--gpg-keep-plaintext"* ]] || {
  echo "wizard should not keep plaintext when prompt answer is no" >&2
  echo "$args_joined" >&2
  exit 1
}
[[ "$SUMMARY_DIR" == "/tmp/support-fixture" ]] || {
  echo "wizard summary dir mismatch: $SUMMARY_DIR" >&2
  exit 1
}
[[ "$SUMMARY_REDACT" == "1" ]] || {
  echo "wizard summary redact mismatch: $SUMMARY_REDACT" >&2
  exit 1
}

echo "menu pack logs wizard ok"
