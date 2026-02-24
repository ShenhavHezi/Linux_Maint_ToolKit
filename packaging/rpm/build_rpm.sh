#!/usr/bin/env bash
set -euo pipefail

TMPDIR="${TMPDIR:-/tmp}"

# Build an RPM using rpmbuild.
# Usage:
#   ./packaging/rpm/build_rpm.sh [version]

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
SPEC="$ROOT/packaging/rpm/linux-maint.spec"
VERSION="${1:-$(cat "$ROOT/VERSION" 2>/dev/null || echo 0.1.0)}"
OUTDIR="${OUTDIR:-$ROOT/dist}"

WORK="${WORK:-${TMPDIR}/linux-maint-rpmbuild}"
rm -rf "$WORK"
mkdir -p "$WORK"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}

# Create source tarball

# Ensure BUILD_INFO matches VERSION+git sha for this build
SHA="unknown"
if command -v git >/dev/null 2>&1 && [[ -d "$ROOT/.git" ]]; then
  SHA="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
fi

"$ROOT/tools/gen_build_info.sh" >/dev/null 2>&1 || true
TARBALL="$WORK/SOURCES/linux-maint-${VERSION}.tar.gz"

tmpdir="$WORK/src/linux-maint-${VERSION}"
mkdir -p "$tmpdir"
# Copy repo content into tarball source dir (exclude .git and local logs)
rsync -a --delete \
  --exclude '.git' --exclude '.logs*' --exclude 'dist' --exclude '__pycache__' \
  "$ROOT/" "$tmpdir/" >/dev/null

tar -C "$WORK/src" -czf "$TARBALL" "linux-maint-${VERSION}"

# Build
rpmbuild \
  --define "commit $SHA" \
  --define "_topdir $WORK" \
  --define "version $VERSION" \
  -ba "$SPEC"

echo "RPMs built under: $WORK/RPMS"
find "$WORK/RPMS" -type f -name '*.rpm' -maxdepth 3 -print

# Copy artifacts to a stable output directory
out_rpm_dir="$OUTDIR/rpm"
mkdir -p "$out_rpm_dir"
find "$WORK/RPMS" -type f -name '*.rpm' -maxdepth 3 -exec cp -a {} "$out_rpm_dir/" \;
echo "RPMs copied to: $out_rpm_dir"
