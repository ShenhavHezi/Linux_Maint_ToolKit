#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

mkdir -p "$workdir/src"

cat > "$workdir/src/safe.txt" <<'S'
hello world
S

# Positive detection should fail.
cat > "$workdir/src/secret.txt" <<'S'
aws_key = AKIAABCDEFGHIJKLMNOP
S

set +e
out_fail="$(bash "$ROOT_DIR/tools/secret_scan.sh" --path "$workdir/src" --allowlist "$workdir/allowlist.txt" 2>&1)"
rc_fail=$?
set -e
if [[ "$rc_fail" -eq 0 ]]; then
  echo "expected secret scan to fail on detected secret" >&2
  exit 1
fi
echo "$out_fail" | grep -q 'Potential secrets detected:'

# Allowlist should suppress known fixture line.
echo 'secret.txt:1:aws_key = AKIAABCDEFGHIJKLMNOP' > "$workdir/allowlist.txt"
out_ok="$(bash "$ROOT_DIR/tools/secret_scan.sh" --path "$workdir/src" --allowlist "$workdir/allowlist.txt")"
echo "$out_ok" | grep -q '^secret scan ok$'

echo "secret scan lint ok"
