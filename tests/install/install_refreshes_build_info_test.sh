#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$ROOT_DIR/tests/testlib.sh"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

repo="$workdir/repo"
prefix="$workdir/prefix"
cfg="$workdir/etc_linux_maint"
logdir="$workdir/var_log_health"
statedir="$workdir/var_lib_linux_maint"
expected_version="$(tr -d '\r' < "$ROOT_DIR/VERSION" | head -n 1 | awk '{print $1}')"

testlib_copy_repo_worktree "$repo"
testlib_init_git_repo "$repo"

cat > "$repo/BUILD_INFO" <<'EOF'
format=linux_maint_build_info
schema_version=1
version=0.1.3
commit=deadbeef
build_time_utc=2026-02-19T11:30:19Z
ci_run_id=
ci_run_attempt=
ci_ref=
ci_sha=
EOF

(
  cd "$repo"
  LM_INSTALL_SKIP_ROOT_CHECK=1 \
  LM_INSTALL_CFG_DIR="$cfg" \
  LM_INSTALL_LOG_DIR="$logdir" \
  LM_INSTALL_STATE_DIR="$statedir" \
  bash ./install.sh --prefix "$prefix" >/dev/null
)

out="$("$prefix/bin/linux-maint" version)"
printf '%s\n' "$out" | grep -q "^version=$expected_version$" || {
  echo "install.sh did not refresh BUILD_INFO from current checkout version" >&2
  echo "$out" >&2
  exit 1
}
if printf '%s\n' "$out" | grep -q '^version=0.1.3$'; then
  echo "install.sh preserved stale checkout BUILD_INFO version" >&2
  echo "$out" >&2
  exit 1
fi

echo "install refreshes build info ok"
