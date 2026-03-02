#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

valid="$workdir/index_valid.json"
cat > "$valid" <<'JSON'
{
  "plugins": [
    {
      "name": "ok_plugin",
      "version": "1.0.0",
      "description": "ok",
      "source": "/tmp/ok_plugin",
      "trust": "community",
      "compatibility": { "min_cli_version": "0.3.0" },
      "signature": { "type": "none", "value": "" }
    }
  ]
}
JSON

bash "$LM" plugin lint-index --index "$valid" --strict >/dev/null

invalid="$workdir/index_invalid.json"
cat > "$invalid" <<'JSON'
{
  "plugins": [
    {
      "name": "bad plugin space",
      "version": "",
      "description": "bad",
      "source": "",
      "trust": "enterprise"
    }
  ]
}
JSON

set +e
bash "$LM" plugin lint-index --index "$invalid" --strict >/dev/null 2>&1
rc=$?
set -e
[[ "$rc" -eq 2 ]] || {
  echo "expected lint-index strict failure rc=2, got rc=$rc" >&2
  exit 1
}

json_out="$(bash "$LM" plugin lint-index --index "$invalid" --json --strict 2>/dev/null || true)"
printf '%s\n' "$json_out" | grep -q '"ok": false' || {
  echo "plugin lint-index json should report ok=false" >&2
  echo "$json_out" >&2
  exit 1
}

echo "plugin index lint ok"
