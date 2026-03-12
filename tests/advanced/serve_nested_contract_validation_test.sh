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
case "${1:-}" in
  status)
    printf '%s\n' '{"status_json_contract_version":1,"last_status":{"overall":"OK","run_id":"run-serve-001"},"totals":{"CRIT":0,"WARN":0,"UNKNOWN":0,"SKIP":0,"OK":1}}'
    ;;
  report)
    printf '%s\n' '{"report_json_contract_version":1,"status":{"last_status":{"overall":"OK"}},"trend":{"trend_json_contract_version":1,"rows":[]},"runtimes":{"runtimes_json_contract_version":1,"rows":[],"files":[],"unit":"ms"}}'
    ;;
  metrics)
    printf '%s\n' '{"metrics_json_contract_version":1,"status":{"last_status":{"overall":"OK"}},"severity_totals":{"CRIT":0,"WARN":0,"UNKNOWN":0,"SKIP":0,"OK":1}}'
    ;;
  history)
    printf '%s\n' '{"history_json_contract_version":1,"runs":[]}'
    ;;
  *)
    printf '%s\n' '{}'
    ;;
esac
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
    raise SystemExit("serve nested-contract test could not reach /health")

for path, command, detail in (
    ("/report", "report --json", "report payload missing nested status contract version"),
    ("/metrics", "metrics --json", "metrics payload missing nested status contract version"),
):
    try:
        urllib.request.urlopen(base + path, timeout=1.0)
    except urllib.error.HTTPError as e:
        assert e.code == 500
        payload = json.loads(e.read().decode("utf-8"))
        assert payload["error"] == "invalid_contract", payload
        assert payload["command"] == command, payload
        assert payload["detail"] == detail, payload
    else:
        raise SystemExit(f"expected {path} to fail with HTTP 500 for nested contract mismatch")
PY

echo "serve nested contract validation ok"
