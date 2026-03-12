#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

fake_cli="$workdir/fake-linux-maint"
cat > "$fake_cli" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "status" && "${2:-}" == "--json" ]]; then
  printf '%s\n' 'not-json'
  exit 0
fi
printf '%s\n' '{}'
SH
chmod +x "$fake_cli"

port="$(python3 - <<'PY'
import socket
s = socket.socket()
s.bind(("127.0.0.1", 0))
print(s.getsockname()[1])
s.close()
PY
)"

LM_SERVE_CLI="$fake_cli" bash "$LM" serve --host 127.0.0.1 --port "$port" >/dev/null 2>&1 &
srv_pid=$!
cleanup() {
  kill "$srv_pid" >/dev/null 2>&1 || true
  wait "$srv_pid" >/dev/null 2>&1 || true
}
trap cleanup EXIT

PORT="$port" python3 - <<'PY'
import json, os, time, urllib.error, urllib.request

port = int(os.environ["PORT"])
base = f"http://127.0.0.1:{port}"

for _ in range(50):
    try:
        with urllib.request.urlopen(base + "/health", timeout=1.0) as r:
            data = json.loads(r.read().decode("utf-8"))
        assert data.get("ok") is True
        break
    except Exception:
        time.sleep(0.1)
else:
    raise SystemExit("serve invalid-json test could not reach /health")

try:
    urllib.request.urlopen(base + "/status", timeout=1.0)
except urllib.error.HTTPError as e:
    assert e.code == 500
    payload = json.loads(e.read().decode("utf-8"))
    assert payload["error"] == "invalid_json"
    assert payload["command"] == "status --json"
else:
    raise SystemExit("expected /status to fail with HTTP 500 for invalid JSON upstream")
PY

echo "serve invalid upstream json ok"
