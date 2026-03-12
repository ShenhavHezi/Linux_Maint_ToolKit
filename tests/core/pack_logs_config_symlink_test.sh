#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

logdir="$workdir/logs"
cfgdir="$workdir/etc_linux_maint"
statedir="$workdir/state"
outdir="$workdir/out"
mkdir -p "$logdir" "$cfgdir" "$statedir" "$outdir"

target_cfg="$cfgdir/plugin.db"
printf 'binary-ish-config\n' > "$target_cfg"
ln -s "$(basename "$target_cfg")" "$cfgdir/plugin-current.db"

bundle_path="$(OUTDIR="$outdir" LOG_DIR="$logdir" CFG_DIR="$cfgdir" STATE_DIR="$statedir" "$ROOT_DIR/tools/pack_logs.sh")"
[[ -f "$bundle_path" ]] || {
  echo "pack-logs did not create bundle" >&2
  exit 1
}

entry_line="$(tar -tvzf "$bundle_path" | grep './config/plugin-current.db')"
case "$entry_line" in
  -*) ;;
  *)
    echo "expected config symlink to be stored as a regular file, got: $entry_line" >&2
    exit 1
    ;;
esac

extracted="$workdir/extracted_plugin_current.db"
tar -xOf "$bundle_path" ./config/plugin-current.db > "$extracted"
grep -q '^binary-ish-config$' "$extracted" || {
  echo "pack-logs did not dereference config symlink content" >&2
  cat "$extracted" >&2
  exit 1
}

echo "pack-logs config symlink ok"
