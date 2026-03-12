#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT_DIR/tests/testlib.sh"

install_script="$ROOT_DIR/install.sh"
rpm_spec="$ROOT_DIR/packaging/rpm/linux-maint.spec"
verify_tool="$ROOT_DIR/tools/verify_release.sh"
upgrade_tool="$ROOT_DIR/tools/upgrade_release.sh"
admin_lib="$ROOT_DIR/lib/linux_maint_admin.sh"

while IFS= read -r lib_name; do
  grep -Fq "lib/RELEASE_LIBS.txt" "$verify_tool" || {
    echo "verify_release.sh no longer consumes the release lib manifest" >&2
    exit 1
  }
  grep -Fq "find \"\$prefix/lib\" -maxdepth 1 -type f -name 'linux_maint*.sh'" "$upgrade_tool" || {
    echo "upgrade_release.sh no longer inventories installed release libs dynamically" >&2
    exit 1
  }
  # shellcheck disable=SC2016
  grep -Fq 'RELEASE_LIBS_FILE="$SCRIPT_DIR/lib/RELEASE_LIBS.txt"' "$install_script" || {
    echo "install.sh no longer consumes the release lib manifest" >&2
    exit 1
  }
  grep -Fq 'done < lib/RELEASE_LIBS.txt' "$rpm_spec" || {
    echo "rpm spec no longer consumes the release lib manifest" >&2
    exit 1
  }
  grep -Fq 'packaging/rpm/support_lib_files.list' "$rpm_spec" || {
    echo "rpm spec no longer generates support lib file entries from the manifest" >&2
    exit 1
  }
  grep -Fq "$lib_name" "$admin_lib" || {
    echo "verify-install helper missing check for $lib_name" >&2
    exit 1
  }
done < <(testlib_release_libs)

echo "support lib payload parity ok"
