#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
CURRENT_VERSION="$(head -n 1 "$ROOT_DIR/VERSION" | tr -d '[:space:]')"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

. "$ROOT_DIR/tests/testlib.sh"

release_repo="$workdir/release_repo"
testlib_copy_repo_worktree "$release_repo"
testlib_build_release_tarball "$release_repo"

tarball="$(find "$release_repo/dist" -maxdepth 1 -type f -name "Linux_Maint_ToolKit-v${CURRENT_VERSION}-*.tgz" | head -n 1)"
[[ -f "$tarball" ]] || {
  echo "expected release tarball for version $CURRENT_VERSION" >&2
  exit 1
}

prefix="$workdir/prefix"
cfg="$workdir/etc_linux_maint"
logdir="$workdir/var_log_health"
statedir="$workdir/var_lib_linux_maint"
lockdir="$workdir/lock"
systemd_dir="$workdir/systemd"
logrotate_file="$workdir/logrotate/linux_maint"
mkdir -p "$lockdir"

(
  cd "$ROOT_DIR"
  LM_INSTALL_SKIP_ROOT_CHECK=1 \
  LM_INSTALL_CFG_DIR="$cfg" \
  LM_INSTALL_LOG_DIR="$logdir" \
  LM_INSTALL_STATE_DIR="$statedir" \
  LM_INSTALL_SYSTEMD_DIR="$systemd_dir" \
  LM_INSTALL_LOGROTATE_FILE="$logrotate_file" \
  bash ./install.sh --prefix "$prefix" >/dev/null
)

printf '%s\n' localhost > "$cfg/servers.txt"
: > "$cfg/excluded.txt"
: > "$cfg/services.txt"

out="$(
  LM_UPGRADE_SKIP_ROOT_CHECK=1 \
  LM_INSTALL_SKIP_ROOT_CHECK=1 \
  LM_INSTALL_SYSTEMD_DIR="$systemd_dir" \
  LM_INSTALL_LOGROTATE_FILE="$logrotate_file" \
  LM_LOCKDIR="$lockdir" \
  "$prefix/bin/linux-maint" upgrade "$tarball" \
    --sums "$release_repo/dist/SHA256SUMS" \
    --rollback-tarball "$tarball" \
    --prefix "$prefix" \
    --cfg-dir "$cfg" \
    --log-dir "$logdir" \
    --state-dir "$statedir" \
    --with-timer \
    --with-logrotate
)"

printf '%s\n' "$out" | grep -q '^upgrade ok$' || {
  echo "upgrade with override layout did not complete successfully" >&2
  echo "$out" >&2
  exit 1
}

[[ -f "$systemd_dir/linux-maint.service" ]] || {
  echo "upgrade did not honor LM_INSTALL_SYSTEMD_DIR for service file" >&2
  exit 1
}

[[ -f "$systemd_dir/linux-maint.timer" ]] || {
  echo "upgrade did not honor LM_INSTALL_SYSTEMD_DIR for timer file" >&2
  exit 1
}

[[ -f "$logrotate_file" ]] || {
  echo "upgrade did not honor LM_INSTALL_LOGROTATE_FILE" >&2
  exit 1
}

manifest="$(find "$statedir/upgrades" -type f -name upgrade_manifest.json | sort | tail -n 1)"
[[ -f "$manifest" ]] || {
  echo "upgrade override layout did not write a manifest" >&2
  exit 1
}

MANIFEST_PATH="$manifest" python3 - <<'PY'
import json
import os

manifest = json.load(open(os.environ["MANIFEST_PATH"], "r", encoding="utf-8"))
assert manifest["status"] == "success"
assert manifest["verify_install_rc"] == 0
PY

echo "upgrade override layout ok"
