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
  grep -Fq "lib/$lib_name" "$verify_tool" || {
    echo "verify_release.sh missing required member for $lib_name" >&2
    exit 1
  }
  grep -Fq "lib/$lib_name" "$upgrade_tool" || {
    echo "upgrade_release.sh missing rollback manifest entry for $lib_name" >&2
    exit 1
  }
  grep -Fq "lib/$lib_name" "$install_script" || {
    echo "install.sh missing install payload reference for $lib_name" >&2
    exit 1
  }
  grep -Fq "rm -f \"\$prefix/lib/$lib_name\"" "$install_script" || {
    echo "install.sh uninstall missing cleanup for $lib_name" >&2
    exit 1
  }
  grep -Fq "install -m 0755 lib/$lib_name %{buildroot}/usr/lib/$lib_name" "$rpm_spec" || {
    echo "rpm spec missing install step for $lib_name" >&2
    exit 1
  }
  grep -Fq "/usr/lib/$lib_name" "$rpm_spec" || {
    echo "rpm spec missing shipped file entry for $lib_name" >&2
    exit 1
  }
  grep -Fq "$lib_name" "$admin_lib" || {
    echo "verify-install helper missing check for $lib_name" >&2
    exit 1
  }
done < <(testlib_release_libs)

echo "support lib payload parity ok"
