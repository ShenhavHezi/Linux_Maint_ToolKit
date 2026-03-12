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

(
  cd "$ROOT_DIR"
  LM_INSTALL_SKIP_ROOT_CHECK=1 \
  LM_INSTALL_CFG_DIR="$cfg" \
  LM_INSTALL_LOG_DIR="$logdir" \
  LM_INSTALL_STATE_DIR="$statedir" \
  bash ./install.sh --prefix "$prefix" >/dev/null
)

json_out="$(
  "$prefix/bin/linux-maint" upgrade "$tarball" \
    --check \
    --json \
    --sums "$release_repo/dist/SHA256SUMS"
)"

printf '%s' "$json_out" | python3 "$ROOT_DIR/tools/json_schema_validate.py" "$ROOT_DIR/docs/schemas/upgrade_check.json"

CURRENT_VERSION="$CURRENT_VERSION" python3 - <<'PY' "$json_out"
import json
import os
import sys

payload = json.loads(sys.argv[1])

assert payload["upgrade_check_json_contract_version"] == 1, payload
assert payload["current_version"] == os.environ["CURRENT_VERSION"], payload
assert payload["target_version"] == os.environ["CURRENT_VERSION"], payload
assert payload["relation"] == "same", payload
assert payload["target_date_utc"], payload
assert payload["release_notes_rel"] == f"docs/release_notes/release_notes_v{os.environ['CURRENT_VERSION']}.md", payload
assert payload["checks"]["release_notes_found"] is True, payload
assert payload["checks"]["upgrade_guide_found"] is True, payload
assert payload["checks"]["sums_supplied"] is True, payload
assert payload["checks"]["sig_supplied"] is False, payload
assert payload["highlights"], payload
assert payload["compatibility_notes"], payload
assert "target release matches the installed version" in payload["warnings"], payload
assert payload["next_steps"], payload
assert payload["result"] == "WARN", payload
PY

echo "upgrade check command ok"

human_out="$(
  "$prefix/bin/linux-maint" upgrade "$tarball" \
    --check \
    --sums "$release_repo/dist/SHA256SUMS"
)"

printf '%s\n' "$human_out" | grep -q '^== Guidance ==$' || {
  echo "upgrade check guidance header missing" >&2
  echo "$human_out" >&2
  exit 1
}
printf '%s\n' "$human_out" | grep -q '^== Summary ==$' || {
  echo "upgrade check summary header missing" >&2
  echo "$human_out" >&2
  exit 1
}
printf '%s\n' "$human_out" | grep -q '^checks: release_notes=ok upgrade_guide=ok sums=yes sig=no$' || {
  echo "upgrade check checks line missing" >&2
  echo "$human_out" >&2
  exit 1
}
printf '%s\n' "$human_out" | grep -q '^Compatibility notes:$' || {
  echo "upgrade check compatibility notes missing" >&2
  echo "$human_out" >&2
  exit 1
}
printf '%s\n' "$human_out" | grep -q '^upgrade check warn$' || {
  echo "upgrade check final label missing" >&2
  echo "$human_out" >&2
  exit 1
}
