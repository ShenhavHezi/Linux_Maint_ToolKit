#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
REL="$ROOT_DIR/tools/release.sh"

out="$(bash "$REL" 9.9.9 --dry-run --allow-dirty 2>&1 || true)"
printf '%s\n' "$out" | grep -q 'would run: ./tools/release_check.sh' || {
  echo "release.sh dry-run missing release_check invocation" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q 'would run: ./tools/release_audit.sh' || {
  echo "release.sh dry-run missing release_audit invocation" >&2
  echo "$out" >&2
  exit 1
}

out_tarball="$(bash "$REL" 9.9.9 --dry-run --allow-dirty --with-tarball 2>&1 || true)"
printf '%s\n' "$out_tarball" | grep -q 'would build tarball, verify it, and update checksum/provenance in notes' || {
  echo "release.sh dry-run missing tarball verification/provenance note" >&2
  echo "$out_tarball" >&2
  exit 1
}

out_skip="$(bash "$REL" 9.9.9 --dry-run --allow-dirty --skip-checks 2>&1 || true)"
if printf '%s\n' "$out_skip" | grep -q 'would run: ./tools/release_check.sh'; then
  echo "release.sh --skip-checks should skip check call in dry-run output" >&2
  echo "$out_skip" >&2
  exit 1
fi

echo "release.sh checks behavior ok"
