#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

repo="$workdir/repo"
mkdir -p "$repo"
(
  cd "$ROOT_DIR"
  git ls-files -z | tar --null -T - -cf - | tar -xf - -C "$repo"
)

(
  cd "$repo"
  git -c init.defaultBranch=main init >/dev/null
  git config user.name test
  git config user.email test@example.com
  git add .
  git commit -m "test repo" >/dev/null

  bash ./tools/gen_build_info.sh >/dev/null
  OUTDIR="$repo/dist" bash ./tools/make_tarball.sh >/dev/null
  version="$(head -n 1 VERSION | tr -d '[:space:]')"
  tarball="$(find dist -maxdepth 1 -type f -name "Linux_Maint_ToolKit-v${version}-*.tgz" | head -n 1)"
  [[ -n "$tarball" && -f "$tarball" ]] || {
    echo "make_tarball.sh did not create expected tarball name for version $version" >&2
    exit 1
  }
  bash ./tools/verify_release.sh "$tarball" --sums dist/SHA256SUMS >/dev/null
)

echo "make tarball roundtrip ok"
