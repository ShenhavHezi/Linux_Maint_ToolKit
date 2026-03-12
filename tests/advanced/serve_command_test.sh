#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

port="$(python3 - <<'PY'
import socket
s = socket.socket()
s.bind(("127.0.0.1", 0))
print(s.getsockname()[1])
s.close()
PY
)"

bash "$LM" serve --host 127.0.0.1 --port "$port" >/dev/null 2>&1 &
srv_pid=$!
cleanup() {
  kill "$srv_pid" >/dev/null 2>&1 || true
  wait "$srv_pid" >/dev/null 2>&1 || true
}
trap cleanup EXIT

PORT="$port" python3 - <<'PY'
import json, os, time, urllib.request

port = int(os.environ["PORT"])
base = f"http://127.0.0.1:{port}"

def get_json(path):
    with urllib.request.urlopen(base + path, timeout=1.0) as r:
        return json.loads(r.read().decode("utf-8"))

last_err = None
for _ in range(50):
    try:
        health = get_json("/health")
        assert health.get("ok") is True
        routes = get_json("/")
        rs = routes.get("routes") or []
        assert "/status" in rs and "/report" in rs
        break
    except Exception as e:
        last_err = e
        time.sleep(0.1)
else:
    raise SystemExit(f"serve endpoint check failed: {last_err}")
PY

echo "serve command ok"
