#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

index_dir="$workdir/index"
mkdir -p "$index_dir"
printf '[]\n' > "$workdir/plugins.json"
sha="$(sha256sum "$workdir/plugins.json" | awk '{print $1}')"

cat > "$index_dir/index.json" <<JSON
{
  "plugins": [],
  "attestation": {
    "type": "sha256",
    "target": "../plugins.json",
    "value": "$sha"
  }
}
JSON

set +e
json_out="$(bash "$LM" plugin verify-index --index "$index_dir/index.json" --json --strict 2>&1)"
rc=$?
set -e

[[ "$rc" -eq 2 ]] || {
  echo "expected plugin verify-index rc=2 for escaping attestation target, got rc=$rc" >&2
  echo "$json_out" >&2
  exit 1
}

printf '%s\n' "$json_out" | grep -q 'attestation target escapes index dir' || {
  echo "expected escape warning in plugin verify-index output" >&2
  echo "$json_out" >&2
  exit 1
}

echo "plugin verify-index path escape ok"
