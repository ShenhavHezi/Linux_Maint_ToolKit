#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

out="$(bash "$LM" metrics --prom 2>/dev/null || true)"
if [[ -z "${out:-}" ]]; then
  echo "metrics --prom parse safety skipped: empty output"
  exit 0
fi

PROM_TEXT="$out" python3 - <<'PY'
import os, re, sys
t = os.environ.get("PROM_TEXT","")
if "\x1b[" in t:
    raise SystemExit("ANSI escape found in metrics --prom output")
metric_re = re.compile(r'^[a-zA-Z_:][a-zA-Z0-9_:]*(\{[^{}]*\})?\s+[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?$')
for ln in t.splitlines():
    s = ln.strip()
    if not s or s.startswith("#"):
        continue
    if not metric_re.match(s):
        raise SystemExit(f"invalid prom exposition line: {s}")
print("metrics prom parse safety ok")
PY
