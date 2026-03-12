#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

logdir="$workdir/logs"
mkdir -p "$logdir"
cat > "$logdir/full_health_monitor_latest.log" <<'EOF'
one
two
three
EOF

out="$(LOG_DIR="$logdir" bash "$LM" logs 2)"
expected=$'two\nthree'
[[ "$out" == "$expected" ]] || {
  echo "unexpected logs output" >&2
  printf 'expected:\n%s\nactual:\n%s\n' "$expected" "$out" >&2
  exit 1
}

echo "logs basic ok"
