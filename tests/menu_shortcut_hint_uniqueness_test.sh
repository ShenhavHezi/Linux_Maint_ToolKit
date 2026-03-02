#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

python3 - "$LM" <<'PY'
import re
import sys

path = sys.argv[1]
text = open(path, "r", encoding="utf-8").read()

prompts = [
    "Choose your next step",
    "Run checks",
    "Reports and status",
    "Tools and automation",
    "Help and docs",
    "Diagnostics and recovery",
    "Config and inventory",
    "Menu settings",
    "Incident mode",
    "Status drilldown",
]

for prompt in prompts:
    m = re.search(rf'tui_menu_prompt_safe "{re.escape(prompt)}" \\\n(.*?)\)\n', text, re.S)
    if not m:
        raise SystemExit(f"menu block not found: {prompt}")
    block = m.group(1)
    descs = []
    for line in block.splitlines():
        lm = re.match(r'^\s*[A-Za-z0-9_]+\s+"([^"]+)"\s*\\?$', line)
        if lm:
            descs.append(lm.group(1))
    if not descs:
        raise SystemExit(f"no menu entries found: {prompt}")
    hints = []
    for d in descs:
        hm = re.search(r"\[([A-Za-z0-9])\]", d)
        if not hm:
            raise SystemExit(f"missing [key] hint in menu '{prompt}': {d}")
        hints.append(hm.group(1).lower())
    dup = sorted({k for k in hints if hints.count(k) > 1})
    if dup:
        raise SystemExit(f"duplicate [key] hints in menu '{prompt}': {', '.join(dup)}")

print("menu shortcut hint uniqueness ok")
PY
