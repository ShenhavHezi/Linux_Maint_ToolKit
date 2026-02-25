#!/usr/bin/env bash
# Verify offline release artifact integrity (checksum + optional detached signature)
set -euo pipefail

usage(){
  cat <<USAGE
Usage: $0 <tarball> [--sums FILE] [--sig FILE]

Examples:
  $0 dist/Linux_Maint_ToolKit-*.tgz
  $0 dist/Linux_Maint_ToolKit-*.tgz --sums dist/SHA256SUMS
  $0 dist/Linux_Maint_ToolKit-*.tgz --sums dist/SHA256SUMS --sig dist/Linux_Maint_ToolKit-*.tgz.asc

Behavior:
- Always verifies SHA256 checksum from SHA256SUMS (default next to tarball).
- If --sig is provided, verifies detached signature with gpg.
USAGE
}

[[ $# -ge 1 ]] || { usage >&2; exit 2; }

TARBALL="$1"; shift
SUMS_FILE=""
SIG_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sums) SUMS_FILE="$2"; shift 2 ;;
    --sig) SIG_FILE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -f "$TARBALL" ]] || { echo "ERROR: tarball not found: $TARBALL" >&2; exit 1; }

if [[ -z "$SUMS_FILE" ]]; then
  SUMS_FILE="$(dirname "$TARBALL")/SHA256SUMS"
fi
[[ -f "$SUMS_FILE" ]] || { echo "ERROR: checksum file not found: $SUMS_FILE" >&2; exit 1; }

base="$(basename "$TARBALL")"
line="$(grep -E "[[:space:]]${base}$" "$SUMS_FILE" || true)"
[[ -n "$line" ]] || { echo "ERROR: checksum entry for $base not found in $SUMS_FILE" >&2; exit 1; }

(
  cd "$(dirname "$TARBALL")"
  printf '%s\n' "$line" | sha256sum -c -
)

echo "checksum verification ok: $base"

tar_version=""
tar_sha=""
if [[ "$base" =~ Linux_Maint_ToolKit-(v[0-9]+\.[0-9]+\.[0-9]+)-([0-9a-f]+)\.tgz$ ]]; then
  tar_version="${BASH_REMATCH[1]}"
  tar_sha="${BASH_REMATCH[2]}"
fi

build_info="$(tar -xOf "$TARBALL" BUILD_INFO 2>/dev/null || true)"
version_file="$(tar -xOf "$TARBALL" VERSION 2>/dev/null || true)"
if [[ -z "$build_info" || -z "$version_file" ]]; then
  echo "ERROR: tarball missing BUILD_INFO or VERSION" >&2
  exit 1
fi

build_version="$(printf '%s\n' "$build_info" | awk -F= '$1=="version"{print $2}' | head -n 1)"
build_commit="$(printf '%s\n' "$build_info" | awk -F= '$1=="commit"{print $2}' | head -n 1)"
version_file="$(printf '%s' "$version_file" | head -n 1)"

if [[ -n "$tar_version" && "$build_version" != "$tar_version" ]]; then
  echo "ERROR: BUILD_INFO version mismatch (tar=$tar_version build=$build_version)" >&2
  exit 1
fi
if [[ -n "$tar_version" ]]; then
  expected_version="${tar_version#v}"
  if [[ "$version_file" != "$expected_version" ]]; then
    echo "ERROR: VERSION file mismatch (tar=$expected_version file=$version_file)" >&2
    exit 1
  fi
fi
if [[ -n "$tar_sha" && -n "$build_commit" && "$build_commit" != "$tar_sha" ]]; then
  echo "ERROR: BUILD_INFO commit mismatch (tar=$tar_sha build=$build_commit)" >&2
  exit 1
fi
echo "tarball metadata verification ok"

if [[ -n "$SIG_FILE" ]]; then
  [[ -f "$SIG_FILE" ]] || { echo "ERROR: signature file not found: $SIG_FILE" >&2; exit 1; }
  command -v gpg >/dev/null 2>&1 || { echo "ERROR: gpg required for signature verification" >&2; exit 1; }
  gpg --verify "$SIG_FILE" "$TARBALL" >/dev/null 2>&1
  echo "signature verification ok: $(basename "$SIG_FILE")"
fi

echo "release verification ok"
