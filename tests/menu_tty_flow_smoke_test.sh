#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

if ! command -v script >/dev/null 2>&1; then
  echo "menu tty flow smoke skipped: script not found"
  exit 0
fi
if ! command -v gum >/dev/null 2>&1; then
  echo "menu tty flow smoke skipped: gum not found"
  exit 0
fi

out="$(mktemp)"
cleanup() { rm -f "$out"; }
trap cleanup EXIT

# Pseudo-TTY smoke: menu should render immediately with visible choices.
set +e
timeout 6s script -qfec "TERM=xterm LM_TUI_BACKEND=gum LM_TUI_COMPACT=1 \"$LM\" menu" /dev/null >"$out" 2>&1
rc=$?
set -e
[[ "$rc" -eq 124 ]] || {
  echo "menu tty flow smoke expected timeout rc=124, got rc=$rc" >&2
  sed -n '1,120p' "$out" >&2 || true
  exit 1
}
grep -q "Operations console" "$out" || {
  echo "menu tty flow smoke missing operations console header in pseudo-TTY output" >&2
  sed -n '1,120p' "$out" >&2 || true
  exit 1
}
grep -q "Dashboard, current state, and next moves" "$out" || {
  echo "menu tty flow smoke missing menu choices in pseudo-TTY output" >&2
  sed -n '1,120p' "$out" >&2 || true
  exit 1
}
grep -q "overview=" "$out" || {
  echo "menu tty flow smoke missing compact overview line" >&2
  sed -n '1,160p' "$out" >&2 || true
  exit 1
}
grep -q "next=" "$out" || {
  echo "menu tty flow smoke missing compact next-step guidance" >&2
  sed -n '1,160p' "$out" >&2 || true
  exit 1
}
echo "menu tty flow smoke ok"
