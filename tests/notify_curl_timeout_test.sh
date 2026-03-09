#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT
fakebin="$workdir/bin"
args_file="$workdir/curl.args"
mkdir -p "$fakebin"

cat > "$fakebin/curl" <<'EOF_CURL'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$ARGS_FILE"
exit 0
EOF_CURL
chmod +x "$fakebin/curl"

PATH="$fakebin:$PATH" \
ARGS_FILE="$args_file" \
LM_NOTIFY_CONNECT_TIMEOUT=7 \
LM_NOTIFY_MAX_TIME=19 \
bash "$LM" notify --provider slack --url https://example.invalid/webhook --message hi >/dev/null

grep -Fxq -- '--connect-timeout' "$args_file" || {
  echo "notify curl missing --connect-timeout" >&2
  cat "$args_file" >&2
  exit 1
}
grep -Fxq -- '7' "$args_file" || {
  echo "notify curl missing configured connect timeout" >&2
  cat "$args_file" >&2
  exit 1
}
grep -Fxq -- '--max-time' "$args_file" || {
  echo "notify curl missing --max-time" >&2
  cat "$args_file" >&2
  exit 1
}
grep -Fxq -- '19' "$args_file" || {
  echo "notify curl missing configured max time" >&2
  cat "$args_file" >&2
  exit 1
}

echo "notify curl timeout ok"
