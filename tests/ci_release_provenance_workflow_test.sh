#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
ci="$ROOT_DIR/.github/workflows/ci.yml"
release_notes="$ROOT_DIR/.github/workflows/release_notes.yml"

assert_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if ! grep -Fq -- "$pattern" "$file"; then
    echo "$message" >&2
    exit 1
  fi
}

assert_absent() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if grep -Fq -- "$pattern" "$file"; then
    echo "$message" >&2
    exit 1
  fi
}

assert_contains "$ci" 'uses: actions/checkout@v5' \
  "ci workflow did not upgrade checkout to v5"
assert_contains "$release_notes" 'uses: actions/checkout@v5' \
  "release notes workflow did not upgrade checkout to v5"
assert_absent "$ci" 'uses: actions/checkout@v3' \
  "ci workflow still references checkout v3"
assert_absent "$ci" 'uses: actions/checkout@v4' \
  "ci workflow still references checkout v4"
assert_absent "$release_notes" 'uses: actions/checkout@v4' \
  "release notes workflow still references checkout v4"

assert_contains "$ci" 'uses: actions/attest@v4' \
  "ci workflow missing artifact attestation step"
assert_contains "$ci" 'attestations: write' \
  "ci workflow missing attestations write permission"
assert_contains "$ci" 'id-token: write' \
  "ci workflow missing id-token write permission for attestations"
assert_contains "$ci" 'dist/release_provenance.json' \
  "release workflow no longer uploads provenance manifest"

echo "ci release provenance workflow ok"
