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

run_plan_preview="$(tui_command_preview_body "linux-maint run --plan" "$0" run --plan)"
[[ "$run_plan_preview" == *"Risk:"* ]] || {
  echo "command preview missing risk section" >&2
  echo "$run_plan_preview" >&2
  exit 1
}
[[ "$run_plan_preview" == *"config from $LM_CFG_DIR"* ]] || {
  echo "run preview missing cfg read path" >&2
  echo "$run_plan_preview" >&2
  exit 1
}
[[ "$run_plan_preview" == *"no host changes; plan output only"* ]] || {
  echo "run --plan preview missing write summary" >&2
  echo "$run_plan_preview" >&2
  exit 1
}
[[ "$run_plan_preview" == *"Review scope and expected skips"* ]] || {
  echo "run --plan preview missing next-step hint" >&2
  echo "$run_plan_preview" >&2
  exit 1
}

pack_preview="$(tui_command_preview_body "linux-maint pack-logs" "$0" pack-logs --out /tmp/bundle.tgz --redact)"
[[ "$pack_preview" == *"support bundle artifacts in the selected output directory"* ]] || {
  echo "pack-logs preview missing write target summary" >&2
  echo "$pack_preview" >&2
  exit 1
}
[[ "$pack_preview" == *"Share the generated artifact"* ]] || {
  echo "pack-logs preview missing next-step hint" >&2
  echo "$pack_preview" >&2
  exit 1
}

doctor_fix_preview="$(tui_command_preview_body "linux-maint doctor --fix" "$0" doctor --fix)"
[[ "$doctor_fix_preview" == *"Changes system"* ]] || {
  echo "doctor --fix preview should be risky" >&2
  echo "$doctor_fix_preview" >&2
  exit 1
}
[[ "$doctor_fix_preview" == *"may repair directories, permissions, or dependencies"* ]] || {
  echo "doctor --fix preview missing write summary" >&2
  echo "$doctor_fix_preview" >&2
  exit 1
}

echo "menu command preview ok"
