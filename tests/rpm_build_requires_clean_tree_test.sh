#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT_DIR/tests/testlib.sh"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

repo="$workdir/repo"
testlib_copy_repo_tracked "$repo"
testlib_init_git_repo "$repo"

printf '# dirty rpm build test\n' >> "$repo/README.md"

set +e
out="$(OUTDIR="$workdir/out" WORK="$workdir/rpmbuild" "$repo/packaging/rpm/build_rpm.sh" 2>&1)"
rc=$?
set -e

[[ "$rc" -ne 0 ]] || {
  echo "build_rpm.sh succeeded on a dirty git checkout" >&2
  exit 1
}

grep -q 'working tree not clean' <<< "$out" || {
  echo "build_rpm.sh did not explain dirty checkout failure" >&2
  echo "$out" >&2
  exit 1
}

echo "rpm build clean tree guard ok"
