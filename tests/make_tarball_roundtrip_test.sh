#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

repo="$workdir/repo"
mkdir -p "$repo"
. "$ROOT_DIR/tests/testlib.sh"
testlib_copy_repo_tracked "$repo"

(
  cd "$repo"
  testlib_init_git_repo "$repo"
  bash ./tools/gen_build_info.sh >/dev/null
  OUTDIR="$repo/dist" bash ./tools/make_tarball.sh >/dev/null
  version="$(head -n 1 VERSION | tr -d '[:space:]')"
  tarball="$(find dist -maxdepth 1 -type f -name "Linux_Maint_ToolKit-v${version}-*.tgz" | head -n 1)"
  manifest="dist/release_provenance.json"
  [[ -n "$tarball" && -f "$tarball" ]] || {
    echo "make_tarball.sh did not create expected tarball name for version $version" >&2
    exit 1
  }
  [[ -f "$manifest" ]] || {
    echo "make_tarball.sh did not create release provenance manifest" >&2
    exit 1
  }
  bash ./tools/verify_release.sh "$tarball" --sums dist/SHA256SUMS --manifest "$manifest" >/dev/null
)

echo "make tarball roundtrip ok"
