#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

safe_opts='-o BatchMode=yes -o ConnectTimeout=3 -o StrictHostKeyChecking=accept-new'
out_safe="$(bash "$LM" run --dry-run --ssh-opts "$safe_opts")"
printf '%s\n' "$out_safe" | grep -q '^Resolved hosts '

assert_unsafe() {
  local bad="$1"
  local out rc

  set +e
  out="$(bash "$LM" run --dry-run --ssh-opts "$bad" 2>&1)"
  rc=$?
  set -e

  if [[ "$rc" -ne 2 ]]; then
    echo "expected rc=2 for unsafe opts, got rc=$rc opts=$bad" >&2
    echo "$out" >&2
    exit 1
  fi

  printf '%s\n' "$out" | grep -q 'ERROR: unsafe characters detected' || {
    echo "missing unsafe-options error for opts: $bad" >&2
    echo "$out" >&2
    exit 1
  }
}

assert_unsafe '-o BatchMode=yes;id'
assert_unsafe '-o BatchMode=yes | cat'
assert_unsafe '-o ProxyCommand=$(id)'
assert_unsafe '-o ProxyCommand=`id`'
assert_unsafe '-o UserKnownHostsFile=/tmp/kh < /dev/null'

echo "ssh opts validation ok"
