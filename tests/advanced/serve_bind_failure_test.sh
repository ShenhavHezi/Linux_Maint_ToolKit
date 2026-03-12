#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

port="$(python3 - <<'PY'
import socket
s = socket.socket()
s.bind(("127.0.0.1", 0))
print(s.getsockname()[1])
s.close()
PY
)"

python3 - "$port" <<'PY' &
import socket
import sys
import time

port = int(sys.argv[1])
s = socket.socket()
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(("127.0.0.1", port))
s.listen(1)
time.sleep(10)
PY
blocker_pid=$!
cleanup() {
  kill "$blocker_pid" >/dev/null 2>&1 || true
  wait "$blocker_pid" >/dev/null 2>&1 || true
}
trap cleanup EXIT
sleep 0.2

set +e
out="$(bash "$LM" serve --host 127.0.0.1 --port "$port" 2>&1)"
rc=$?
set -e

[[ "$rc" -eq 1 ]] || {
  echo "expected serve bind failure rc=1, got rc=$rc" >&2
  echo "$out" >&2
  exit 1
}

printf '%s\n' "$out" | grep -q "ERROR: serve failed to bind 127.0.0.1:$port:" || {
  echo "unexpected serve bind failure output" >&2
  echo "$out" >&2
  exit 1
}

echo "serve bind failure ok"
