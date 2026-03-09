#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REAL_LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

fake_lm="$workdir/linux-maint"
cp "$REAL_LM" "$fake_lm"
perl -0pi -e 's@st_json="\$\(NO_COLOR=1 \"\$0\" status --json --reasons 8 --problems 12 2>/dev/null\)"@st_json="$(printf '\''%s\\n'\'' '\''{not-json'\'')"\nst_rc=0@' "$fake_lm"
chmod +x "$fake_lm"

set +e
out="$(bash "$fake_lm" ai-assist --json 2>&1)"
rc=$?
set -e

if [[ "$rc" -ne 2 ]]; then
  echo "expected ai-assist invalid status failure rc=2, got rc=$rc" >&2
  echo "$out" >&2
  exit 1
fi

printf '%s\n' "$out" | grep -q '^ERROR: ai-assist requires valid JSON from status --json$' || {
  echo "unexpected ai-assist invalid status output" >&2
  echo "$out" >&2
  exit 1
}

echo "ai-assist invalid status ok"
