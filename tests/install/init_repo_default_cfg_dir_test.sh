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

(
  cd "$repo"
  bash ./bin/linux-maint init --minimal >/dev/null
)

cfg_dir="$repo/.etc_linux_maint"
for required in servers.txt excluded.txt services.txt; do
  [[ -f "$cfg_dir/$required" ]] || {
    echo "repo-mode init did not create $required under $cfg_dir" >&2
    exit 1
  }
done

echo "init repo default cfg dir ok"
