#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
script="$ROOT_DIR/install.sh"
# shellcheck disable=SC2016
verify_pattern='tools/verify_release.sh "$libexec/verify_release.sh"'
# shellcheck disable=SC2016
upgrade_pattern='tools/upgrade_release.sh "$libexec/upgrade_release.sh"'
# shellcheck disable=SC2016
version_install_pattern='install -m 0644 VERSION "$prefix/share/linux_maint/VERSION"'
# shellcheck disable=SC2016
plugin_index_install_pattern='install -m 0644 plugins/index.json "$prefix/share/linux_maint/plugins/index.json"'
# shellcheck disable=SC2016
bin_remove_pattern='rm -f "$prefix/bin/linux-maint"'
# shellcheck disable=SC2016
conf_remove_pattern='rm -f "$prefix/lib/linux_maint_conf.sh"'
# shellcheck disable=SC2016
share_remove_pattern='rm -rf "$prefix/share/linux_maint"'

grep -Fq "$verify_pattern" "$script" || {
  echo "install.sh no longer installs verify_release.sh into libexec" >&2
  exit 1
}

grep -Fq "$upgrade_pattern" "$script" || {
  echo "install.sh no longer installs upgrade_release.sh into libexec" >&2
  exit 1
}

grep -Fq "$version_install_pattern" "$script" || {
  echo "install.sh no longer installs VERSION into share/linux_maint" >&2
  exit 1
}

grep -Fq "$plugin_index_install_pattern" "$script" || {
  echo "install.sh no longer installs the packaged plugin index into share/linux_maint/plugins" >&2
  exit 1
}

grep -Fq "$bin_remove_pattern" "$script" || {
  echo "install.sh uninstall no longer removes installed linux-maint binary" >&2
  exit 1
}

grep -Fq "$conf_remove_pattern" "$script" || {
  echo "install.sh uninstall no longer removes linux_maint_conf.sh" >&2
  exit 1
}

grep -Fq "$share_remove_pattern" "$script" || {
  echo "install.sh uninstall no longer removes share/linux_maint payloads" >&2
  exit 1
}

echo "install manifest ok"
