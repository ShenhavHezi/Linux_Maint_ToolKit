#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$ROOT_DIR/tests/testlib.sh"
spec="$ROOT_DIR/packaging/rpm/linux-maint.spec"

assert_contains() {
  local pattern="$1"
  local message="$2"
  if ! grep -Fq -- "$pattern" "$spec"; then
    echo "$message" >&2
    exit 1
  fi
}

assert_contains ': > packaging/rpm/support_lib_files.list' \
  "rpm spec no longer prepares a generated support lib file list"
assert_contains 'done < lib/RELEASE_LIBS.txt' \
  "rpm spec no longer consumes lib/RELEASE_LIBS.txt"
assert_contains 'install -m 0644 lib/RELEASE_LIBS.txt %{buildroot}/usr/lib/RELEASE_LIBS.txt' \
  "rpm spec no longer installs the release lib manifest into /usr/lib"
assert_contains 'install -m 0755 tools/pack_logs.sh %{buildroot}/usr/libexec/linux_maint/pack_logs.sh' \
  "rpm spec no longer installs pack_logs.sh"
assert_contains 'install -m 0755 tools/verify_release.sh %{buildroot}/usr/libexec/linux_maint/verify_release.sh' \
  "rpm spec no longer installs verify_release.sh"
assert_contains 'install -m 0755 tools/upgrade_release.sh %{buildroot}/usr/libexec/linux_maint/upgrade_release.sh' \
  "rpm spec no longer installs upgrade_release.sh"
assert_contains 'install -d %{buildroot}/etc/linux_maint/conf.d' \
  "rpm spec no longer creates /etc/linux_maint/conf.d"
assert_contains 'install -d %{buildroot}/etc/linux_maint/baselines' \
  "rpm spec no longer creates /etc/linux_maint/baselines"
assert_contains 'install -m 0644 VERSION %{buildroot}/usr/share/linux_maint/VERSION' \
  "rpm spec no longer installs VERSION into share/linux_maint"
assert_contains 'install -m 0644 plugins/index.json %{buildroot}/usr/share/linux_maint/plugins/index.json' \
  "rpm spec no longer installs the packaged plugin index"
assert_contains 'if [ -f BUILD_INFO ]; then' \
  "rpm spec no longer conditionally installs BUILD_INFO"
assert_contains '%files -f packaging/rpm/support_lib_files.list' \
  "rpm spec no longer ships generated support lib file entries"
assert_contains '/usr/lib/RELEASE_LIBS.txt' \
  "rpm spec no longer ships /usr/lib/RELEASE_LIBS.txt"
assert_contains '%dir /usr/libexec/linux_maint' \
  "rpm spec no longer owns /usr/libexec/linux_maint"
assert_contains '%dir /etc/linux_maint/conf.d' \
  "rpm spec no longer ships /etc/linux_maint/conf.d"
assert_contains '%dir /etc/linux_maint/baselines' \
  "rpm spec no longer ships /etc/linux_maint/baselines"

grep -Fq 'linux_maint_config.sh' "$ROOT_DIR/lib/RELEASE_LIBS.txt" || {
  echo "release lib manifest no longer includes linux_maint_config.sh" >&2
  exit 1
}
grep -Fq 'linux_maint_diag.sh' "$ROOT_DIR/lib/RELEASE_LIBS.txt" || {
  echo "release lib manifest no longer includes linux_maint_diag.sh" >&2
  exit 1
}

echo "rpm manifest ok"
