#!/usr/bin/env bash
# Verify offline release artifact integrity (checksum + optional detached signature)
set -euo pipefail

usage(){
  cat <<USAGE
Usage: $0 <tarball> [--sums FILE] [--sig FILE] [--manifest FILE]

Examples:
  $0 dist/Linux_Maint_ToolKit-*.tgz
  $0 dist/Linux_Maint_ToolKit-*.tgz --sums dist/SHA256SUMS
  $0 dist/Linux_Maint_ToolKit-*.tgz --sums dist/SHA256SUMS --sig dist/Linux_Maint_ToolKit-*.tgz.asc
  $0 dist/Linux_Maint_ToolKit-*.tgz --sums dist/SHA256SUMS --manifest dist/release_provenance.json

Behavior:
- Always verifies SHA256 checksum from SHA256SUMS (default next to tarball).
- If --sig is provided, verifies detached signature with gpg.
- If --manifest is provided, verifies release provenance metadata. If omitted,
  sibling dist/release_provenance.json is validated when present.
USAGE
}

[[ $# -ge 1 ]] || { usage >&2; exit 2; }

TARBALL="$1"; shift
SUMS_FILE=""
SIG_FILE=""
MANIFEST_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sums) SUMS_FILE="$2"; shift 2 ;;
    --sig) SIG_FILE="$2"; shift 2 ;;
    --manifest) MANIFEST_FILE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -f "$TARBALL" ]] || { echo "ERROR: tarball not found: $TARBALL" >&2; exit 1; }

if [[ -z "$SUMS_FILE" ]]; then
  SUMS_FILE="$(dirname "$TARBALL")/SHA256SUMS"
fi
[[ -f "$SUMS_FILE" ]] || { echo "ERROR: checksum file not found: $SUMS_FILE" >&2; exit 1; }
if [[ -z "$MANIFEST_FILE" ]]; then
  candidate_manifest="$(dirname "$TARBALL")/release_provenance.json"
  if [[ -f "$candidate_manifest" ]]; then
    MANIFEST_FILE="$candidate_manifest"
  fi
fi

base="$(basename "$TARBALL")"
line="$(grep -E "[[:space:]]${base}$" "$SUMS_FILE" || true)"
[[ -n "$line" ]] || { echo "ERROR: checksum entry for $base not found in $SUMS_FILE" >&2; exit 1; }

(
  cd "$(dirname "$TARBALL")"
  printf '%s\n' "$line" | sha256sum -c -
)

echo "checksum verification ok: $base"
actual_sha="$(sha256sum "$TARBALL" | awk '{print $1}')"

tar_version=""
tar_sha=""
if [[ "$base" =~ Linux_Maint_ToolKit-(v[0-9]+\.[0-9]+\.[0-9]+)-([0-9a-f]+)\.tgz$ ]]; then
  tar_version="${BASH_REMATCH[1]}"
  tar_sha="${BASH_REMATCH[2]}"
fi

extract_tar_member(){
  local tarball="$1" member="$2"
  local value=""
  value="$(tar -xOf "$tarball" "$member" 2>/dev/null || true)"
  if [[ -n "$value" ]]; then
    printf '%s' "$value"
    return 0
  fi
  value="$(tar -xOf "$tarball" "./$member" 2>/dev/null || true)"
  printf '%s' "$value"
}

tar_member_exists(){
  local members="$1" member="$2"
  grep -Fxq -- "$member" <<< "$members"
}

required_nonlib_tar_members(){
  cat <<'EOF'
install.sh
bin/linux-maint
run_full_health_monitor.sh
lib/RELEASE_LIBS.txt
tools/verify_release.sh
tools/upgrade_release.sh
tools/pack_logs.sh
tools/seed_known_hosts.sh
tools/summary_diff.py
plugins/index.json
VERSION
BUILD_INFO
EOF
}

build_info="$(extract_tar_member "$TARBALL" BUILD_INFO)"
version_file="$(extract_tar_member "$TARBALL" VERSION)"
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

tar_members="$(tar -tf "$TARBALL" | sed 's#^\./##' | sort -u)"
while IFS= read -r member; do
  [[ -n "$member" ]] || continue
  if ! tar_member_exists "$tar_members" "$member"; then
    echo "ERROR: tarball missing required member: $member" >&2
    exit 1
  fi
done < <(required_nonlib_tar_members)
release_libs_manifest="$(extract_tar_member "$TARBALL" lib/RELEASE_LIBS.txt)"
[[ -n "$release_libs_manifest" ]] || {
  echo "ERROR: tarball missing release lib manifest content" >&2
  exit 1
}
while IFS= read -r lib_name; do
  [[ -n "$lib_name" ]] || continue
  if ! tar_member_exists "$tar_members" "lib/$lib_name"; then
    echo "ERROR: tarball missing required lib member: lib/$lib_name" >&2
    exit 1
  fi
done <<< "$release_libs_manifest"
if [[ -n "$tar_version" ]]; then
  release_note_member="docs/release_notes/release_notes_${tar_version}.md"
  if ! tar_member_exists "$tar_members" "$release_note_member"; then
    echo "ERROR: tarball missing release notes for $tar_version: $release_note_member" >&2
    exit 1
  fi
fi
echo "tarball contents verification ok"

if [[ -n "$MANIFEST_FILE" ]]; then
  [[ -f "$MANIFEST_FILE" ]] || { echo "ERROR: provenance manifest not found: $MANIFEST_FILE" >&2; exit 1; }
  command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 required for provenance manifest verification" >&2; exit 1; }
  MANIFEST_FILE="$MANIFEST_FILE" \
  EXPECTED_ARTIFACT="$base" \
  EXPECTED_SHA256="$actual_sha" \
  EXPECTED_VERSION="${tar_version#v}" \
  EXPECTED_TAG="$tar_version" \
  EXPECTED_COMMIT="$tar_sha" \
  python3 - <<'PY'
import json
import os
import sys

manifest_path = os.environ["MANIFEST_FILE"]
with open(manifest_path, "r", encoding="utf-8") as fh:
    payload = json.load(fh)

if payload.get("release_provenance_version") != 1:
    raise SystemExit(f"ERROR: unsupported release provenance version in {manifest_path}")

checks = {
    "artifact": os.environ["EXPECTED_ARTIFACT"],
    "sha256": os.environ["EXPECTED_SHA256"],
}
expected_version = os.environ.get("EXPECTED_VERSION")
expected_tag = os.environ.get("EXPECTED_TAG")
expected_commit = os.environ.get("EXPECTED_COMMIT")
if expected_version:
    checks["version"] = expected_version
if expected_tag:
    checks["tag"] = expected_tag
if expected_commit:
    checks["commit"] = expected_commit

for key, expected in checks.items():
    actual = payload.get(key)
    if actual != expected:
      raise SystemExit(f"ERROR: provenance manifest mismatch for {key}: expected {expected}, got {actual}")
PY
  echo "provenance manifest verification ok: $(basename "$MANIFEST_FILE")"
fi

if [[ -n "$SIG_FILE" ]]; then
  [[ -f "$SIG_FILE" ]] || { echo "ERROR: signature file not found: $SIG_FILE" >&2; exit 1; }
  command -v gpg >/dev/null 2>&1 || { echo "ERROR: gpg required for signature verification" >&2; exit 1; }
  gpg --verify "$SIG_FILE" "$TARBALL" >/dev/null 2>&1
  echo "signature verification ok: $(basename "$SIG_FILE")"
fi

echo "release verification ok"
