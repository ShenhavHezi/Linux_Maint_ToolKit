#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

prefix="$workdir/prefix"
cfg="$workdir/etc/linux_maint"
logdir="$workdir/var/log/health"
statedir="$workdir/var/lib/linux_maint"
unitdir="$workdir/systemd"
logrotate="$workdir/logrotate/linux_maint"

mkdir -p "$unitdir" "$(dirname "$logrotate")"
printf '%s\n' 'old-service' > "$unitdir/linux-maint.service"
printf '%s\n' 'old-timer' > "$unitdir/linux-maint.timer"
printf '%s\n' 'old-logrotate' > "$logrotate"

set +e
out="$(
  cd "$ROOT_DIR"
  LM_INSTALL_SKIP_ROOT_CHECK=1 \
  LM_INSTALL_CFG_DIR="$cfg" \
  LM_INSTALL_LOG_DIR="$logdir" \
  LM_INSTALL_STATE_DIR="$statedir" \
  LM_INSTALL_SYSTEMD_DIR="$unitdir" \
  LM_INSTALL_LOGROTATE_FILE="$logrotate" \
  LM_INSTALL_FAIL_AT=after_systemd_write \
  bash ./install.sh --prefix "$prefix" --with-logrotate --with-timer 2>&1
)"
rc=$?
set -e

if [[ "$rc" -eq 0 ]]; then
  echo "expected systemd/logrotate rollback failure path to exit non-zero" >&2
  exit 1
fi

grep -q '^Install failed; restoring previous payloads$' <<<"$out" || {
  echo "install.sh did not announce rollback for systemd/logrotate failure" >&2
  echo "$out" >&2
  exit 1
}

grep -q '^old-service$' "$unitdir/linux-maint.service" || {
  echo "install.sh did not restore previous service unit" >&2
  exit 1
}

grep -q '^old-timer$' "$unitdir/linux-maint.timer" || {
  echo "install.sh did not restore previous timer unit" >&2
  exit 1
}

grep -q '^old-logrotate$' "$logrotate" || {
  echo "install.sh did not restore previous logrotate file" >&2
  exit 1
}

echo "install rollback systemd/logrotate failure ok"
