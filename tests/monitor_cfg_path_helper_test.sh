#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
inode_thresholds_pattern="THRESHOLDS=\"\${THRESHOLDS:-\$(lm_cfg_path inode_thresholds.txt)}\""
inode_exclude_pattern="EXCLUDE_MOUNTS=\"\${EXCLUDE_MOUNTS:-\$(lm_cfg_path inode_exclude.txt)}\""
services_pattern="SERVICES=\"\${SERVICES:-\$(lm_cfg_path services.txt)}\""
disk_trend_pattern="EXCLUDE_MOUNTS_FILE=\"\${EXCLUDE_MOUNTS_FILE:-\$(lm_cfg_path disk_trend_exclude_mounts.txt)}\""

assert_contains() {
  local path="$1" pattern="$2" message="$3"
  grep -F -q -- "$pattern" "$path" || {
    echo "$message" >&2
    exit 1
  }
}

assert_contains "$ROOT_DIR/monitors/inode_monitor.sh" \
  "$inode_thresholds_pattern" \
  "inode_monitor no longer resolves thresholds through lm_cfg_path"

assert_contains "$ROOT_DIR/monitors/inode_monitor.sh" \
  "$inode_exclude_pattern" \
  "inode_monitor no longer resolves exclude mounts through lm_cfg_path"

assert_contains "$ROOT_DIR/monitors/service_monitor.sh" \
  "$services_pattern" \
  "service_monitor no longer resolves services.txt through lm_cfg_path"

assert_contains "$ROOT_DIR/monitors/disk_trend_monitor.sh" \
  "$disk_trend_pattern" \
  "disk_trend_monitor no longer resolves disk_trend_exclude_mounts.txt through lm_cfg_path"

echo "monitor cfg path helper ok"
