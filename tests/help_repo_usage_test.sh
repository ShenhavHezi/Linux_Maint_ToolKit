#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

out="$(bash "$LM" help 2>&1 || true)"

printf '%s\n' "$out" | grep -F -q '(repo mode; git checkout)' || {
  echo "top-level help missing repo quick start" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q '^  init \[flags\][[:space:]]\+Install config templates into <cfg_dir>$' || {
  echo "top-level help still uses installed-only init wording" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q '^  config \[flags\][[:space:]]\+Show effective config (merged from <cfg_dir>)$' || {
  echo "top-level help still uses installed-only config wording" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q '^  linux-maint lint-summary <summary.log>$' || {
  echo "top-level help should use generic lint-summary example" >&2
  echo "$out" >&2
  exit 1
}

run_help="$(bash "$LM" help run)"
printf '%s\n' "$run_help" | grep -q '^  --group G            use <cfg_dir>/hosts.d/G.txt$' || {
  echo "run help should describe repo/install-neutral group path" >&2
  echo "$run_help" >&2
  exit 1
}

echo "help repo usage ok"
