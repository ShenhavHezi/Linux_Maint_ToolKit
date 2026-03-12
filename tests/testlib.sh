#!/usr/bin/env bash

TESTLIB_ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TESTLIB_RELEASE_LIBS_FILE="$TESTLIB_ROOT_DIR/lib/RELEASE_LIBS.txt"

testlib_copy_repo_tracked() {
  local dest="$1"
  mkdir -p "$dest"
  (
    cd "$TESTLIB_ROOT_DIR" || exit
    git -c "safe.directory=$TESTLIB_ROOT_DIR" ls-files -z | while IFS= read -r -d '' path; do
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

testlib_release_libs() {
  if [[ -f "$TESTLIB_RELEASE_LIBS_FILE" ]]; then
    cat "$TESTLIB_RELEASE_LIBS_FILE"
    return 0
  fi
  find "$TESTLIB_ROOT_DIR/lib" -maxdepth 1 -type f -name 'linux_maint*.sh' -printf '%f\n' | LC_ALL=C sort
}

testlib_release_libs_except() {
  local base
  local skip
  while IFS= read -r base; do
    skip=0
    for skip_base in "$@"; do
      if [[ "$base" == "$skip_base" ]]; then
        skip=1
        break
      fi
    done
    [[ "$skip" -eq 0 ]] && printf '%s\n' "$base"
  done < <(testlib_release_libs)
}

testlib_support_libs() {
  testlib_release_libs_except linux_maint.sh linux_maint_conf.sh "$@"
}

testlib_copy_release_libs() {
  local root_dir="$1"
  local dest="$2"
  shift 2
  mkdir -p "$dest"
  while IFS= read -r base; do
    cp "$root_dir/lib/$base" "$dest/$base"
  done < <(testlib_release_libs_except "$@")
  cp "$root_dir/lib/RELEASE_LIBS.txt" "$dest/RELEASE_LIBS.txt"
}

testlib_copy_support_libs() {
  local root_dir="$1"
  local dest="$2"
  shift 2
  mkdir -p "$dest"
  while IFS= read -r base; do
    cp "$root_dir/lib/$base" "$dest/$base"
  done < <(testlib_support_libs "$@")
  cp "$root_dir/lib/RELEASE_LIBS.txt" "$dest/RELEASE_LIBS.txt"
}

testlib_link_release_libs() {
  local root_dir="$1"
  local dest="$2"
  shift 2
  mkdir -p "$dest"
  while IFS= read -r base; do
    ln -s "$root_dir/lib/$base" "$dest/$base"
  done < <(testlib_release_libs_except "$@")
  ln -s "$root_dir/lib/RELEASE_LIBS.txt" "$dest/RELEASE_LIBS.txt"
}

testlib_link_support_libs() {
  local root_dir="$1"
  local dest="$2"
  shift 2
  mkdir -p "$dest"
  while IFS= read -r base; do
    ln -s "$root_dir/lib/$base" "$dest/$base"
  done < <(testlib_support_libs "$@")
  ln -s "$root_dir/lib/RELEASE_LIBS.txt" "$dest/RELEASE_LIBS.txt"
}

testlib_write_release_lib_stubs() {
  local dest="$1"
  mkdir -p "$dest"
  : > "$dest/RELEASE_LIBS.txt"
  while IFS= read -r base; do
    printf '#!/usr/bin/env bash\n' > "$dest/$base"
    printf '%s\n' "$base" >> "$dest/RELEASE_LIBS.txt"
  done < <(testlib_release_libs)
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
