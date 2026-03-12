#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"

cli="$workdir/fake-cli.sh"
cat > "$cli" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  status)
    sleep 2
    printf '%s\n' '{"status":"slow"}'
    ;;
  report|metrics|history)
    printf '%s\n' '{}'
    ;;
  *)
    printf '%s\n' "unexpected command: ${1:-}" >&2
    exit 2
    ;;
esac
SH
chmod +x "$cli"

port="$(python3 - <<'PY'
import socket
s = socket.socket()
s.bind(("127.0.0.1", 0))
print(s.getsockname()[1])
s.close()
PY
)"

LM_SERVE_CLI="$cli" LM_SERVE_CMD_TIMEOUT=1 \
  bash "$LM" serve --host 127.0.0.1 --port "$port" >/dev/null 2>&1 &
srv_pid=$!
cleanup() {
  kill "$srv_pid" >/dev/null 2>&1 || true
  wait "$srv_pid" >/dev/null 2>&1 || true
  rm -rf "$workdir"
}
trap cleanup EXIT

PORT="$port" python3 - <<'PY'
import json, os, threading, time, urllib.error, urllib.request

port = int(os.environ["PORT"])
base = f"http://127.0.0.1:{port}"

def get_json(path, timeout=3.0):
    with urllib.request.urlopen(base + path, timeout=timeout) as r:
        return json.loads(r.read().decode("utf-8"))

last_err = None
for _ in range(50):
    try:
        if get_json("/health").get("ok") is True:
            break
    except Exception as e:
        last_err = e
        time.sleep(0.1)
else:
    raise SystemExit(f"serve endpoint check failed: {last_err}")

result = {}

def fetch_status():
    try:
        urllib.request.urlopen(base + "/status", timeout=3.0)
        raise SystemExit("expected /status timeout failure")
    except urllib.error.HTTPError as e:
        result["status_code"] = e.code
        result["status_body"] = json.loads(e.read().decode("utf-8"))

t = threading.Thread(target=fetch_status)
t.start()
time.sleep(0.2)

started = time.monotonic()
health = get_json("/health", timeout=1.0)
elapsed = time.monotonic() - started
t.join()

assert health.get("ok") is True
assert elapsed < 0.75, elapsed
assert result.get("status_code") == 504, result
assert result.get("status_body", {}).get("error") == "command_timeout", result
assert int(result.get("status_body", {}).get("timeout_seconds", 0)) == 1, result
PY

echo "serve command timeout ok"
