#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
cfg_dir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$cfg_dir"' EXIT

out="$(
  LM_CFG_DIR="$cfg_dir" \
  bash -c '
    . "$1/lib/linux_maint.sh"
    printf "%s\n%s\n%s\n%s\n%s\n%s\n" \
      "$LM_EMAILS" \
      "$LM_EXCLUDED" \
      "$LM_SERVERLIST" \
      "$LM_HOSTS_DIR" \
      "$(lm_cfg_root)" \
      "$(lm_cfg_path services.txt)"
  ' _ "$ROOT_DIR"
)"

expected="$cfg_dir/emails.txt
$cfg_dir/excluded.txt
$cfg_dir/servers.txt
$cfg_dir/hosts.d
$cfg_dir
$cfg_dir/services.txt"

[[ "$out" == "$expected" ]] || {
  echo "LM_CFG_DIR-aware defaults do not match expected values" >&2
  printf 'got:\n%s\nexpected:\n%s\n' "$out" "$expected" >&2
  exit 1
}

echo "lm cfg defaults ok"
