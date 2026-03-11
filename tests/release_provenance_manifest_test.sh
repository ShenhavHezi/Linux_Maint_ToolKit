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
  manifest="dist/release_provenance.json"

  [[ -f "$tarball" ]] || {
    echo "expected tarball missing" >&2
    exit 1
  }
  [[ -f "$manifest" ]] || {
    echo "expected provenance manifest missing" >&2
    exit 1
  }

  TARBALL_PATH="$tarball" MANIFEST_PATH="$manifest" EXPECTED_VERSION="$version" python3 - <<'PY'
import json
import os
from pathlib import Path

tarball = Path(os.environ["TARBALL_PATH"])
manifest = json.loads(Path(os.environ["MANIFEST_PATH"]).read_text(encoding="utf-8"))

assert manifest["release_provenance_version"] == 1
assert manifest["artifact"] == tarball.name
assert manifest["version"] == os.environ["EXPECTED_VERSION"]
assert manifest["tag"] == f"v{os.environ['EXPECTED_VERSION']}"
assert manifest["sha256sums"] == "SHA256SUMS"
assert manifest["build_info"] == "BUILD_INFO"
assert len(manifest["sha256"]) == 64
assert manifest["commit"]
assert manifest["built_at_utc"]
PY
)

echo "release provenance manifest ok"
