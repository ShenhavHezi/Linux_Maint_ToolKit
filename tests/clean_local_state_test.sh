#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

repo="$workdir/repo"
mkdir -p "$repo/tools" "$repo/.logs" "$repo/.tmp_test" "$repo/.etc_linux_maint" "$repo/tools/__pycache__" "$repo/dist"
install -m 0755 "$ROOT_DIR/tools/clean_local_state.sh" "$repo/tools/clean_local_state.sh"
printf 'log\n' > "$repo/.logs/run.log"
printf 'tmp\n' > "$repo/.tmp_test/data"
printf 'cfg\n' > "$repo/.etc_linux_maint/linux-maint.conf"
printf 'cache\n' > "$repo/tools/__pycache__/module.cpython-311.pyc"
printf 'artifact\n' > "$repo/dist/release.tgz"
printf 'build\n' > "$repo/BUILD_INFO"

out="$(cd "$repo" && bash ./tools/clean_local_state.sh --dry-run)"
grep -q '\.logs' <<< "$out" || {
  echo "dry-run output did not include .logs" >&2
  exit 1
}
[[ -d "$repo/.logs" ]] || {
  echo "dry-run removed .logs unexpectedly" >&2
  exit 1
}
[[ -d "$repo/dist" ]] || {
  echo "dry-run removed dist unexpectedly" >&2
  exit 1
}

(cd "$repo" && bash ./tools/clean_local_state.sh >/dev/null)
[[ ! -e "$repo/.logs" && ! -e "$repo/.tmp_test" && ! -e "$repo/.etc_linux_maint" && ! -e "$repo/tools/__pycache__" ]] || {
  echo "default cleanup did not remove local state directories" >&2
  exit 1
}
[[ -e "$repo/dist" ]] || {
  echo "default cleanup removed dist unexpectedly" >&2
  exit 1
}
[[ -e "$repo/BUILD_INFO" ]] || {
  echo "default cleanup removed BUILD_INFO unexpectedly" >&2
  exit 1
}

(cd "$repo" && bash ./tools/clean_local_state.sh --all >/dev/null)
[[ ! -e "$repo/dist" && ! -e "$repo/BUILD_INFO" ]] || {
  echo "--all cleanup did not remove dist and BUILD_INFO" >&2
  exit 1
}

echo "clean local state ok"
