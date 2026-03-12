#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$ROOT_DIR/tests/testlib.sh"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

repo="$workdir/repo"
testlib_copy_repo_tracked "$repo"

custom_log_dir="$repo/custom-logs"
mkdir -p "$custom_log_dir"

set +e
out="$(
  cd "$repo" &&
  LOG_DIR="$custom_log_dir" bash ./bin/linux-maint tune dark-site 2>&1
)"
rc=$?
set -e

if [[ "$rc" -ne 0 ]]; then
  echo "tune dark-site failed in repo mode" >&2
  echo "$out" >&2
  exit 1
fi

conf="$repo/.etc_linux_maint/linux-maint.conf"
[[ -f "$conf" ]] || {
  echo "tune dark-site did not create repo-local config: $conf" >&2
  exit 1
}

grep -F -q "LM_LAST_RUN_LOG_DIR=\"$custom_log_dir\"" "$conf" || {
  echo "tune dark-site did not honor repo LOG_DIR override" >&2
  cat "$conf" >&2
  exit 1
}

echo "tune dark-site repo mode ok"
