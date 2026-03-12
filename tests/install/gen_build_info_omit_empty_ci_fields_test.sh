#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$ROOT_DIR/tests/testlib.sh"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

repo="$workdir/repo"
testlib_copy_repo_worktree "$repo"
testlib_init_git_repo "$repo"

(
  cd "$repo"
  env -u GITHUB_RUN_ID -u GITHUB_RUN_ATTEMPT -u GITHUB_REF -u GITHUB_SHA \
    CI_RUN_ID= CI_RUN_ATTEMPT= CI_REF= CI_SHA= \
    bash ./tools/gen_build_info.sh >/dev/null
)

build_info="$repo/BUILD_INFO"
grep -q '^format=linux_maint_build_info$' "$build_info"
grep -q '^version=' "$build_info"
grep -q '^commit=' "$build_info"
grep -q '^build_time_utc=' "$build_info"
if grep -q '^ci_run_id=' "$build_info"; then
  echo "gen_build_info unexpectedly emitted empty ci_run_id" >&2
  cat "$build_info" >&2
  exit 1
fi
if grep -q '^ci_run_attempt=' "$build_info"; then
  echo "gen_build_info unexpectedly emitted empty ci_run_attempt" >&2
  cat "$build_info" >&2
  exit 1
fi
if grep -q '^ci_ref=' "$build_info"; then
  echo "gen_build_info unexpectedly emitted empty ci_ref" >&2
  cat "$build_info" >&2
  exit 1
fi
if grep -q '^ci_sha=' "$build_info"; then
  echo "gen_build_info unexpectedly emitted empty ci_sha" >&2
  cat "$build_info" >&2
  exit 1
fi

echo "gen build info omit empty ci fields ok"
