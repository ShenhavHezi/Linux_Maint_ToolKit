#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT_DIR/tests/testlib.sh"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

if [[ "$(id -u)" -eq 0 ]]; then
  echo "SKIP: installed advanced read-only root-gate test requires non-root context"
  exit 0
fi

prefix="$workdir/prefix"
mkdir -p "$prefix/bin" "$prefix/sbin" "$prefix/lib" "$prefix/share/linux_maint"

cp "$ROOT_DIR/bin/linux-maint" "$prefix/bin/linux-maint"
chmod +x "$prefix/bin/linux-maint"
testlib_copy_support_libs "$ROOT_DIR" "$prefix/lib"

printf '#!/usr/bin/env bash\nexit 0\n' > "$prefix/sbin/run_full_health_monitor.sh"
chmod +x "$prefix/sbin/run_full_health_monitor.sh"
printf '# library\n' > "$prefix/lib/linux_maint.sh"
printf '# conf helper\n' > "$prefix/lib/linux_maint_conf.sh"
printf 'project=Linux_Maint_ToolKit\nversion=v0.0.0\ncommit=test\n' > "$prefix/share/linux_maint/BUILD_INFO"
printf '0.0.0\n' > "$prefix/share/linux_maint/VERSION"

lm="$prefix/bin/linux-maint"
common_env=(
  "PREFIX=$prefix"
  "NO_COLOR=1"
)

agent_out="$(env "${common_env[@]}" "$lm" agent --once --dry-run 2>&1)"
printf '%s\n' "$agent_out" | grep -q '^agent dry-run iteration=1$' || {
  echo "installed agent --dry-run should run without root" >&2
  echo "$agent_out" >&2
  exit 1
}

fake_cli="$workdir/fake-linux-maint"
cat > "$fake_cli" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  status)
    printf '%s\n' '{"status_json_contract_version":1,"last_status":{"overall":"OK","run_id":"run-serve-001"},"totals":{"CRIT":0,"WARN":0,"UNKNOWN":0,"SKIP":0,"OK":1}}'
    ;;
  report)
    printf '%s\n' '{"report_json_contract_version":1,"status":{"last_status":{"overall":"OK"}},"trend":{"trend_json_contract_version":1,"rows":[]},"runtimes":{"runtimes_json_contract_version":1,"rows":[],"files":[],"unit":"ms"},"run_id":"run-serve-001"}'
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

env "${common_env[@]}" "LM_SERVE_CLI=$fake_cli" "$lm" serve --host 127.0.0.1 --port "$port" >/dev/null 2>&1 &
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

for _ in range(50):
    try:
        with urllib.request.urlopen(base + "/health", timeout=1.0) as r:
            data = json.loads(r.read().decode("utf-8"))
        assert data.get("ok") is True
        break
    except Exception:
        time.sleep(0.1)
else:
    raise SystemExit("installed serve no-root test could not reach /health")

with urllib.request.urlopen(base + "/status", timeout=1.0) as r:
    payload = json.loads(r.read().decode("utf-8"))
assert payload["last_status"]["overall"] == "OK"
assert payload["totals"]["OK"] == 1
PY

echo "installed advanced read-only commands ok"
