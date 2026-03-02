#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"
TMPDIR="${TMPDIR:-/tmp}"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

index_file="$workdir/run_index.jsonl"
python3 - "$index_file" <<'PY'
import json, sys
path = sys.argv[1]
with open(path, "w", encoding="utf-8") as f:
    for i in range(100000):
        row = {
            "ts_utc": f"2026-03-02T00:{(i//60)%60:02d}:{i%60:02d}Z",
            "run_id": f"r{i:06d}",
            "overall": "OK" if i % 10 else "WARN",
            "hosts": {"ok": 10, "warn": 1 if i % 10 == 0 else 0, "crit": 0, "unknown": 0, "skipped": 0},
            "result": {"ok": 100, "warn": 0, "crit": 0, "unknown": 0, "skipped": 0}
        }
        f.write(json.dumps(row, sort_keys=True) + "\n")
PY

start="$(date +%s)"
out="$(LM_RUN_INDEX_FILE="$index_file" bash "$LM" history --json --last 20 2>/dev/null || true)"
end="$(date +%s)"
elapsed=$((end - start))

JSON_OUT="$out" python3 - <<'PY'
import json, os
obj = json.loads(os.environ["JSON_OUT"])
runs = obj.get("runs") or []
assert len(runs) == 20
assert runs[-1].get("run_id") == "r099999"
PY

# Keep threshold generous to reduce CI flakiness while still enforcing bounded behavior.
[[ "$elapsed" -le 15 ]] || {
  echo "history large-index perf regression: ${elapsed}s (>15s)" >&2
  exit 1
}

echo "history large index perf ok (${elapsed}s)"
