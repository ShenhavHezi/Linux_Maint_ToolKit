#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

plug_src="$workdir/signed-plugin"
plug_dir="$workdir/plugins"
mkdir -p "$plug_src"
printf 'payload-v1\n' > "$plug_src/payload.txt"
sig="$(sha256sum "$plug_src/payload.txt" | awk '{print $1}')"
cat > "$plug_src/plugin.json" <<P
{
  "name": "signed_plugin",
  "version": "0.1.0",
  "description": "signed plugin",
  "signature": {
    "type": "sha256",
    "target": "payload.txt",
    "value": "$sig"
  }
}
P

LM_PLUGIN_DIR="$plug_dir" bash "$LM" plugin install "$plug_src" >/dev/null
LM_PLUGIN_DIR="$plug_dir" bash "$LM" plugin verify signed_plugin >/dev/null

# Tamper target file after install; verify should fail.
printf 'payload-v2\n' > "$plug_dir/signed_plugin/payload.txt"
set +e
LM_PLUGIN_DIR="$plug_dir" bash "$LM" plugin verify signed_plugin >/dev/null 2>&1
rc=$?
set -e
[[ "$rc" -eq 2 ]] || {
  echo "expected plugin verify signature failure rc=2, got rc=$rc" >&2
  exit 1
}

json_out="$(LM_PLUGIN_DIR="$plug_dir" bash "$LM" plugin verify signed_plugin --json 2>/dev/null || true)"
printf '%s\n' "$json_out" | grep -q '"signature_ok": false' || {
  echo "expected signature_ok=false in plugin verify json output" >&2
  echo "$json_out" >&2
  exit 1
}

echo "plugin signature verify ok"

# gpg/cosign paths should fail cleanly when signature files/keys are missing.
gpg_src="$workdir/gpg-plugin"
mkdir -p "$gpg_src"
printf 'data\n' > "$gpg_src/payload.txt"
dummy="$(sha256sum "$gpg_src/payload.txt" | awk '{print $1}')"
cat > "$gpg_src/plugin.json" <<P
{
  "name": "gpg_plugin",
  "version": "0.1.0",
  "signature": {
    "type": "gpg",
    "target": "payload.txt",
    "file": "payload.txt.asc",
    "value": "$dummy"
  }
}
P
LM_PLUGIN_DIR="$plug_dir" bash "$LM" plugin install "$gpg_src" >/dev/null
set +e
LM_PLUGIN_DIR="$plug_dir" bash "$LM" plugin verify gpg_plugin >/dev/null 2>&1
rc_gpg=$?
set -e
[[ "$rc_gpg" -eq 2 ]] || {
  echo "expected gpg plugin verify failure rc=2, got rc=$rc_gpg" >&2
  exit 1
}
gpg_json="$(LM_PLUGIN_DIR="$plug_dir" bash "$LM" plugin verify gpg_plugin --json 2>/dev/null || true)"
printf '%s\n' "$gpg_json" | grep -q 'gpg signature file not found' || {
  echo "expected gpg missing signature issue" >&2
  echo "$gpg_json" >&2
  exit 1
}

echo "plugin signature verify extra checks ok"
