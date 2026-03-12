#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT_DIR/tests/testlib.sh"

TMPDIR="${TMPDIR:-/tmp}"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

repo="$workdir/repo"
testlib_copy_repo_tracked "$repo"

cat > "$repo/run_full_health_monitor.sh" <<'SH'
#!/usr/bin/env bash
exit 7
SH
chmod +x "$repo/run_full_health_monitor.sh"

set +e
(
  cd "$repo"
  bash ./bin/linux-maint run --local-only >/dev/null 2>&1
)
rc=$?
set -e

[[ "$rc" -eq 7 ]] || {
  echo "expected run to propagate wrapper exit code 7, got rc=$rc" >&2
  exit 1
}

echo "run wrapper exit code ok"
