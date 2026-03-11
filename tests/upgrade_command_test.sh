#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
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
printf 'marker=keep-me\n' > "$cfg/conf.d/site.conf"
printf '# preserved\n' >> "$cfg/linux-maint.conf"

out="$(
  LM_UPGRADE_SKIP_ROOT_CHECK=1 \
  LM_INSTALL_SKIP_ROOT_CHECK=1 \
  LM_LOCKDIR="$lockdir" \
  "$prefix/bin/linux-maint" upgrade "$tarball" \
    --sums "$release_repo/dist/SHA256SUMS" \
    --rollback-tarball "$tarball" \
    --prefix "$prefix" \
    --cfg-dir "$cfg" \
    --log-dir "$logdir" \
    --state-dir "$statedir"
)"

printf '%s\n' "$out" | grep -q '^upgrade ok$' || {
  echo "upgrade command did not complete successfully" >&2
  echo "$out" >&2
  exit 1
}

manifest="$(find "$statedir/upgrades" -type f -name upgrade_manifest.json | sort | tail -n 1)"
[[ -f "$manifest" ]] || {
  echo "upgrade command did not write a manifest" >&2
  exit 1
}

CURRENT_VERSION="$CURRENT_VERSION" MANIFEST_PATH="$manifest" TARBALL_PATH="$tarball" python3 - <<'PY'
import json
import os

manifest = json.load(open(os.environ["MANIFEST_PATH"], "r", encoding="utf-8"))
assert manifest["status"] == "success"
assert manifest["target_version"] == os.environ["CURRENT_VERSION"]
assert manifest["rollback_artifact"] == os.environ["TARBALL_PATH"]
assert manifest["verify_release_rc"] == 0
assert manifest["install_rc"] == 0
assert manifest["verify_install_rc"] == 0
assert manifest["config_snapshot"]
assert manifest["payload_inventory"]
assert manifest["rollback_instructions"]
PY

[[ -f "$statedir/upgrades/latest/upgrade_manifest.json" ]] || {
  echo "upgrade latest symlink missing" >&2
  exit 1
}

[[ -f "$cfg/conf.d/site.conf" ]] || {
  echo "config override missing after upgrade" >&2
  exit 1
}
grep -q '^marker=keep-me$' "$cfg/conf.d/site.conf" || {
  echo "config override not preserved during upgrade" >&2
  exit 1
}
grep -q '^# preserved$' "$cfg/linux-maint.conf" || {
  echo "linux-maint.conf change not preserved during upgrade" >&2
  exit 1
}

echo "upgrade command ok"
