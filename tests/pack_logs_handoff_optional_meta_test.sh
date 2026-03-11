#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

logdir="$workdir/logs"
cfgdir="$workdir/etc_linux_maint"
statedir="$workdir/state"
mkdir -p "$logdir" "$cfgdir" "$statedir"

bundle_path="$(OUTDIR="$workdir" LOG_DIR="$logdir" CFG_DIR="$cfgdir" STATE_DIR="$statedir" "$ROOT_DIR/tools/pack_logs.sh")"
[[ -f "$bundle_path" ]] || {
  echo "pack-logs did not create bundle" >&2
  exit 1
}

handoff="$workdir/support_handoff.txt"
tar -xOf "$bundle_path" ./meta/support_handoff.txt > "$handoff"

grep -q '^   meta/bundle_manifest\.txt$' "$handoff" || {
  echo "support handoff missing bundle manifest" >&2
  cat "$handoff" >&2
  exit 1
}

grep -q '^   meta/bundle_meta\.txt$' "$handoff" || {
  echo "support handoff missing bundle meta" >&2
  cat "$handoff" >&2
  exit 1
}

grep -q '^   meta/redaction_report\.txt$' "$handoff" || {
  echo "support handoff missing redaction report" >&2
  cat "$handoff" >&2
  exit 1
}

grep -q '^   meta/bundle_hashes\.txt$' "$handoff" && {
  echo "support handoff should not mention hash manifest when hashes are disabled" >&2
  cat "$handoff" >&2
  exit 1
}

echo "pack-logs handoff optional meta ok"
