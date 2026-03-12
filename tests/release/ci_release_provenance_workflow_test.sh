#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
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

assert_contains "$ci" 'uses: actions/checkout@v6' \
  "ci workflow did not upgrade checkout to v6"
assert_contains "$release_notes" 'uses: actions/checkout@v6' \
  "release notes workflow did not upgrade checkout to v6"
assert_absent "$ci" 'uses: actions/checkout@v5' \
  "ci workflow still references checkout v5"
assert_absent "$release_notes" 'uses: actions/checkout@v5' \
  "release notes workflow still references checkout v5"
assert_absent "$ci" 'uses: actions/checkout@v3' \
  "ci workflow still references checkout v3"
assert_absent "$ci" 'uses: actions/checkout@v4' \
  "ci workflow still references checkout v4"
assert_absent "$release_notes" 'uses: actions/checkout@v4' \
  "release notes workflow still references checkout v4"
assert_contains "$ci" 'uses: actions/upload-artifact@v6' \
  "ci workflow did not upgrade upload-artifact to v6"
assert_absent "$ci" 'uses: actions/upload-artifact@v4' \
  "ci workflow still references upload-artifact v4"
assert_contains "$ci" "find tests -type f -name '*.sh'" \
  "ci workflow no longer shellchecks grouped test scripts recursively"
assert_absent "$ci" './tools/shellcheck_wrapper.sh -x tests/*.sh' \
  "ci workflow still shellchecks only top-level tests"
assert_absent "$ci" 'ACTIONS_ALLOW_USE_UNSECURE_NODE_VERSION: true' \
  "ci workflow still allows insecure node runtime"
assert_absent "$ci" 'ubuntu-18.04' \
  "ci workflow still includes ubuntu-18.04 in the compatibility matrix"
assert_contains "$ci" 'ubuntu-24.04' \
  "ci workflow missing ubuntu-24.04 in the compatibility matrix"
assert_contains "$ci" 'debian-12' \
  "ci workflow missing debian-12 in the compatibility matrix"
assert_contains "$ci" 'rockylinux-9' \
  "ci workflow missing rockylinux-9 in the compatibility matrix"

assert_contains "$ci" 'uses: actions/attest@v4' \
  "ci workflow missing artifact attestation step"
assert_contains "$ci" 'attestations: write' \
  "ci workflow missing attestations write permission"
assert_contains "$ci" 'id-token: write' \
  "ci workflow missing id-token write permission for attestations"
assert_contains "$ci" 'dist/release_provenance.json' \
  "release workflow no longer uploads provenance manifest"

echo "ci release provenance workflow ok"
