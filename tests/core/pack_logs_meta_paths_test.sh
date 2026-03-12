#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
script="$ROOT_DIR/tools/pack_logs.sh"

assert_contains() {
  local pattern="$1"
  local message="$2"
  if ! grep -Fq -- "$pattern" "$script"; then
    echo "$message" >&2
    exit 1
  fi
}

assert_contains '"/usr/local/share/linux_maint/BUILD_INFO"' \
  "pack_logs.sh no longer probes installed /usr/local BUILD_INFO"
assert_contains '"/usr/local/share/linux_maint/VERSION"' \
  "pack_logs.sh no longer probes installed /usr/local VERSION"
assert_contains '"/usr/share/linux_maint/BUILD_INFO"' \
  "pack_logs.sh no longer probes installed RPM BUILD_INFO"
assert_contains '"/usr/share/linux_maint/VERSION"' \
  "pack_logs.sh no longer probes installed RPM VERSION"

echo "pack-logs meta paths ok"
