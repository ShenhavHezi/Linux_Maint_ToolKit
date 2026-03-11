#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

copy_repo(){
  local dest="$1"
  mkdir -p "$dest"
  (
    cd "$ROOT_DIR"
    git ls-files -z | while IFS= read -r -d '' path; do
      [[ -e "$path" ]] && printf '%s\0' "$path"
    done | tar --null -T - -cf - | tar -xf - -C "$dest"
  )
}

repo_bad_version="$workdir/repo_bad_version"
copy_repo "$repo_bad_version"
printf '0.3\n' > "$repo_bad_version/VERSION"
set +e
out="$(bash "$repo_bad_version/tools/release_check.sh" 2>&1)"
rc=$?
set -e
[[ "$rc" -ne 0 ]] || {
  echo "release_check.sh succeeded with invalid VERSION format" >&2
  exit 1
}
grep -q 'VERSION must use x.y.z format: 0.3' <<< "$out" || {
  echo "release_check.sh did not flag invalid VERSION format" >&2
  echo "$out" >&2
  exit 1
}

repo_bad_release_arg="$workdir/repo_bad_release_arg"
copy_repo "$repo_bad_release_arg"
(
  cd "$repo_bad_release_arg"
  set +e
  out="$(bash ./tools/release.sh 0.3 --dry-run --allow-dirty 2>&1)"
  rc=$?
  set -e
  [[ "$rc" -ne 0 ]] || {
    echo "release.sh succeeded with invalid version argument" >&2
    exit 1
  }
  grep -q 'version must use x.y.z format: 0.3' <<< "$out" || {
    echo "release.sh did not flag invalid version argument" >&2
    echo "$out" >&2
    exit 1
  }
)

echo "release version format ok"
