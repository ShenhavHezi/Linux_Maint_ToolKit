#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

mkdir -p "$workdir/dist"

tarball="$workdir/dist/linux_Maint_Scripts-test.tgz"
printf 'hello\n' > "$workdir/payload.txt"
( cd "$workdir" && tar -czf "$tarball" payload.txt )

( cd "$workdir/dist" && sha256sum "$(basename "$tarball")" > SHA256SUMS )

# positive path
bash "$ROOT_DIR/tools/verify_release.sh" "$tarball" --sums "$workdir/dist/SHA256SUMS" >/dev/null

# tamper path must fail
printf 'tamper\n' >> "$tarball"
set +e
out="$(bash "$ROOT_DIR/tools/verify_release.sh" "$tarball" --sums "$workdir/dist/SHA256SUMS" 2>&1)"
rc=$?
set -e
if [[ "$rc" -eq 0 ]]; then
  echo "expected checksum verification failure on tampered tarball" >&2
  exit 1
fi
echo "$out" | grep -Eq 'FAILED|No such file|ERROR|warning' || {
  echo "unexpected verify output: $out" >&2
  exit 1
}

echo "release verify ok"
