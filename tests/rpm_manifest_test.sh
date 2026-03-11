#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
spec="$ROOT_DIR/packaging/rpm/linux-maint.spec"

assert_contains() {
  local pattern="$1"
  local message="$2"
  if ! grep -Fq -- "$pattern" "$spec"; then
    echo "$message" >&2
    exit 1
  fi
}

assert_contains 'install -m 0755 lib/linux_maint_conf.sh %{buildroot}/usr/lib/linux_maint_conf.sh' \
  "rpm spec no longer installs linux_maint_conf.sh"
assert_contains 'install -m 0755 lib/linux_maint_runtime.sh %{buildroot}/usr/lib/linux_maint_runtime.sh' \
  "rpm spec no longer installs linux_maint_runtime.sh"
assert_contains 'install -m 0755 lib/linux_maint_admin.sh %{buildroot}/usr/lib/linux_maint_admin.sh' \
  "rpm spec no longer installs linux_maint_admin.sh"
assert_contains 'install -m 0755 lib/linux_maint_tui.sh %{buildroot}/usr/lib/linux_maint_tui.sh' \
  "rpm spec no longer installs linux_maint_tui.sh"
assert_contains 'install -m 0755 lib/linux_maint_config.sh %{buildroot}/usr/lib/linux_maint_config.sh' \
  "rpm spec no longer installs linux_maint_config.sh"
assert_contains 'install -m 0755 lib/linux_maint_reporting.sh %{buildroot}/usr/lib/linux_maint_reporting.sh' \
  "rpm spec no longer installs linux_maint_reporting.sh"
assert_contains 'install -m 0755 lib/linux_maint_advanced.sh %{buildroot}/usr/lib/linux_maint_advanced.sh' \
  "rpm spec no longer installs linux_maint_advanced.sh"
assert_contains 'install -m 0755 lib/linux_maint_history.sh %{buildroot}/usr/lib/linux_maint_history.sh' \
  "rpm spec no longer installs linux_maint_history.sh"
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
assert_contains '/usr/lib/linux_maint_conf.sh' \
  "rpm spec no longer ships linux_maint_conf.sh"
assert_contains '/usr/lib/linux_maint_runtime.sh' \
  "rpm spec no longer ships linux_maint_runtime.sh"
assert_contains '/usr/lib/linux_maint_admin.sh' \
  "rpm spec no longer ships linux_maint_admin.sh"
assert_contains '/usr/lib/linux_maint_tui.sh' \
  "rpm spec no longer ships linux_maint_tui.sh"
assert_contains '/usr/lib/linux_maint_config.sh' \
  "rpm spec no longer ships linux_maint_config.sh"
assert_contains '/usr/lib/linux_maint_reporting.sh' \
  "rpm spec no longer ships linux_maint_reporting.sh"
assert_contains '/usr/lib/linux_maint_advanced.sh' \
  "rpm spec no longer ships linux_maint_advanced.sh"
assert_contains '/usr/lib/linux_maint_history.sh' \
  "rpm spec no longer ships linux_maint_history.sh"
assert_contains '%dir /usr/libexec/linux_maint' \
  "rpm spec no longer owns /usr/libexec/linux_maint"
assert_contains '%dir /etc/linux_maint/conf.d' \
  "rpm spec no longer ships /etc/linux_maint/conf.d"
assert_contains '%dir /etc/linux_maint/baselines' \
  "rpm spec no longer ships /etc/linux_maint/baselines"

echo "rpm manifest ok"
