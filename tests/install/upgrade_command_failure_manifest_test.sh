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
mkdir -p "$lockdir"

(
  cd "$ROOT_DIR"
  LM_INSTALL_SKIP_ROOT_CHECK=1 \
  LM_INSTALL_CFG_DIR="$cfg" \
  LM_INSTALL_LOG_DIR="$logdir" \
  LM_INSTALL_STATE_DIR="$statedir" \
  bash ./install.sh --prefix "$prefix" >/dev/null
)

printf '%s\n' localhost > "$cfg/servers.txt"
: > "$cfg/excluded.txt"
: > "$cfg/services.txt"
before_bin_sha="$(sha256sum "$prefix/bin/linux-maint" | awk '{print $1}')"
before_version="$(head -n 1 "$prefix/share/linux_maint/VERSION" | tr -d '[:space:]')"

set +e
out="$(
  LM_UPGRADE_SKIP_ROOT_CHECK=1 \
  LM_INSTALL_SKIP_ROOT_CHECK=1 \
  LM_INSTALL_FAIL_AT=after_payload_install \
  LM_LOCKDIR="$lockdir" \
  "$prefix/bin/linux-maint" upgrade "$tarball" \
    --sums "$release_repo/dist/SHA256SUMS" \
    --rollback-tarball "$tarball" \
    --prefix "$prefix" \
    --cfg-dir "$cfg" \
    --log-dir "$logdir" \
    --state-dir "$statedir" 2>&1
)"
rc=$?
set -e

[[ "$rc" -ne 0 ]] || {
  echo "upgrade command unexpectedly succeeded on forced install failure" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q '^ERROR: install.sh failed during upgrade' || {
  echo "upgrade command did not report install failure" >&2
  echo "$out" >&2
  exit 1
}

manifest="$(find "$statedir/upgrades" -type f -name upgrade_manifest.json | sort | tail -n 1)"
[[ -f "$manifest" ]] || {
  echo "failure path did not write a manifest" >&2
  exit 1
}

MANIFEST_PATH="$manifest" TARBALL_PATH="$tarball" python3 - <<'PY'
import json
import os

manifest = json.load(open(os.environ["MANIFEST_PATH"], "r", encoding="utf-8"))
assert manifest["status"] == "failed"
assert manifest["rollback_artifact"] == os.environ["TARBALL_PATH"]
assert manifest["verify_release_rc"] == 0
assert manifest["install_rc"] not in (None, 0)
assert manifest["config_snapshot"]
assert manifest["payload_inventory"]
assert manifest["rollback_instructions"]
PY

after_bin_sha="$(sha256sum "$prefix/bin/linux-maint" | awk '{print $1}')"
after_version="$(head -n 1 "$prefix/share/linux_maint/VERSION" | tr -d '[:space:]')"
[[ "$after_bin_sha" == "$before_bin_sha" ]] || {
  echo "installed linux-maint payload changed after failed upgrade" >&2
  exit 1
}
[[ "$after_version" == "$before_version" ]] || {
  echo "installed VERSION changed after failed upgrade" >&2
  exit 1
}

echo "upgrade failure manifest ok"
