#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

dest="$workdir/monitors"
bash "$ROOT_DIR/tools/new_monitor.sh" rpm_style_check --dest "$dest" >/dev/null

template="$dest/rpm_style_check.sh"
[[ -f "$template" ]] || {
  echo "new_monitor.sh did not create the monitor template" >&2
  exit 1
}

# shellcheck disable=SC2016
grep -Fq 'for _lm_lib in "${LINUX_MAINT_LIB:-}" /usr/local/lib/linux_maint.sh /usr/lib/linux_maint.sh; do' "$template" || {
  echo "monitor template missing installed library fallback chain" >&2
  exit 1
}

grep -Fq 'Missing linux_maint library (set LINUX_MAINT_LIB or install linux_maint.sh)' "$template" || {
  echo "monitor template missing actionable library error" >&2
  exit 1
}

echo "new monitor template lib fallback ok"
