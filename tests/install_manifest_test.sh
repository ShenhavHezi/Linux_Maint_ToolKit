#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT_DIR/tests/testlib.sh"
script="$ROOT_DIR/install.sh"
release_libs="$ROOT_DIR/lib/RELEASE_LIBS.txt"

assert_contains() {
  local pattern="$1"
  local message="$2"
  if ! grep -Fq -- "$pattern" "$script"; then
    echo "$message" >&2
    exit 1
  fi
}

# shellcheck disable=SC2016
assert_contains 'RELEASE_LIBS_FILE="$SCRIPT_DIR/lib/RELEASE_LIBS.txt"' \
  "install.sh no longer defines the release lib manifest path"
# shellcheck disable=SC2016
assert_contains 'while IFS= read -r lib_name; do' \
  "install.sh no longer loops over release libs"
# shellcheck disable=SC2016
assert_contains 'done < <(read_release_libs)' \
  "install.sh no longer reads the release lib manifest"
# shellcheck disable=SC2016
assert_contains 'tools/verify_release.sh "$libexec/verify_release.sh"' \
  "install.sh no longer installs verify_release.sh into libexec"
# shellcheck disable=SC2016
assert_contains 'tools/upgrade_release.sh "$libexec/upgrade_release.sh"' \
  "install.sh no longer installs upgrade_release.sh into libexec"
# shellcheck disable=SC2016
assert_contains 'install -m 0644 VERSION "$prefix/share/linux_maint/VERSION"' \
  "install.sh no longer installs VERSION into share/linux_maint"
# shellcheck disable=SC2016
assert_contains 'install -D -m 0644 "$RELEASE_LIBS_FILE" "$lib/RELEASE_LIBS.txt"' \
  "install.sh no longer installs RELEASE_LIBS.txt into the installed lib dir"
# shellcheck disable=SC2016
assert_contains 'install -m 0644 plugins/index.json "$prefix/share/linux_maint/plugins/index.json"' \
  "install.sh no longer installs the packaged plugin index into share/linux_maint/plugins"
# shellcheck disable=SC2016
assert_contains 'rm -f "$prefix/bin/linux-maint"' \
  "install.sh uninstall no longer removes installed linux-maint binary"
# shellcheck disable=SC2016
assert_contains 'rm -rf "$prefix/share/linux_maint"' \
  "install.sh uninstall no longer removes share/linux_maint payloads"
grep -Fq 'linux_maint_config.sh' "$release_libs" || {
  echo "release lib manifest no longer includes linux_maint_config.sh" >&2
  exit 1
}
grep -Fq 'linux_maint_diag.sh' "$release_libs" || {
  echo "release lib manifest no longer includes linux_maint_diag.sh" >&2
  exit 1
}

echo "install manifest ok"
