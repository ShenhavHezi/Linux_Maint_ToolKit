#!/usr/bin/env bash
set -euo pipefail

# Detect read-only mounts (excluding common pseudo FS).
. "${LINUX_MAINT_LIB:-/usr/local/lib/linux_maint.sh}" || { echo "Missing ${LINUX_MAINT_LIB:-/usr/local/lib/linux_maint.sh}"; exit 1; }
LM_PREFIX="[filesystem_readonly_monitor] "
LM_LOGFILE="${LM_LOGFILE:-/var/log/filesystem_readonly_monitor.log}"

lm_require_singleton "filesystem_readonly_monitor"

MOUNTS_FILE="${LM_MOUNTS_FILE:-/proc/mounts}"
EXCLUDE_FSTYPES_RE="${LM_FS_RO_EXCLUDE_RE:-^(proc|sysfs|devtmpfs|tmpfs|devpts|cgroup2?|cgroup|debugfs|tracefs|mqueue|hugetlbfs|pstore|squashfs|overlay|rpc_pipefs|autofs|fuse\\..*|binfmt_misc)$}"

if [[ ! -r "$MOUNTS_FILE" ]]; then
  lm_summary "filesystem_readonly_monitor" "localhost" "UNKNOWN" reason=permission_denied path="$MOUNTS_FILE"
  exit 3
fi

ro_mounts=()
while IFS= read -r line; do
  set -- $line
  dev="$1"; mnt="$2"; fstype="$3"; opts="$4"
  if [[ "$fstype" =~ $EXCLUDE_FSTYPES_RE ]]; then
    continue
  fi
  if echo "$opts" | grep -q '\bro\b'; then
    ro_mounts+=("$mnt")
  fi
done < "$MOUNTS_FILE"

if [[ "${#ro_mounts[@]}" -gt 0 ]]; then
  list="$(printf '%s,' "${ro_mounts[@]}" | sed 's/,$//')"
  lm_summary "filesystem_readonly_monitor" "localhost" "WARN" reason=filesystem_readonly count="${#ro_mounts[@]}" mounts="$list"
  exit 0
fi

lm_summary "filesystem_readonly_monitor" "localhost" "OK"
exit 0
