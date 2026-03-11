#!/usr/bin/env bash

TESTLIB_ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

testlib_copy_repo_tracked() {
  local dest="$1"
  mkdir -p "$dest"
  (
    cd "$TESTLIB_ROOT_DIR" || exit
    git ls-files -z | while IFS= read -r -d '' path; do
      [[ -e "$path" ]] && printf '%s\0' "$path"
    done | tar --null -T - -cf - | tar -xf - -C "$dest"
  )
}

testlib_copy_repo_worktree() {
  local dest="$1"
  mkdir -p "$dest"
  (
    cd "$TESTLIB_ROOT_DIR" || exit
    tar \
      --exclude=.git \
      --exclude=dist \
      --exclude=.logs \
      --exclude=.tmp_test \
      --exclude=.etc_linux_maint \
      --exclude=tools/__pycache__ \
      -cf - .
  ) | tar -xf - -C "$dest"
}

testlib_init_git_repo() {
  local repo="$1"
  (
    cd "$repo" || exit
    git -c init.defaultBranch=main init >/dev/null
    git config user.name test
    git config user.email test@example.com
    git add .
    git commit -m "test repo" >/dev/null
  )
}

testlib_build_release_tarball() {
  local repo="$1"
  testlib_init_git_repo "$repo"
  (
    cd "$repo" || exit
    bash ./tools/gen_build_info.sh >/dev/null 2>&1
    OUTDIR="$repo/dist" bash ./tools/make_tarball.sh >/dev/null
  )
}
