#!/usr/bin/env python3
"""Lint: ensure monitor= summary lines are machine-parseable and safe.

Contract (high level):
- Each summary line is space-separated key=value tokens.
- Required keys: monitor, host, status, node
- No duplicate keys within a line.
- Values must not contain unescaped whitespace (i.e., tokenization by spaces must be stable).
- Key-budget guardrails: global max keys with optional per-monitor overrides.
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path

REQUIRED = {"monitor", "host", "status", "node"}
VALID_STATUS = {"OK", "WARN", "CRIT", "UNKNOWN", "SKIP"}
DEFAULT_MAX_KEYS = 18
# Explicit exceptions for noisier monitors; keep this short and intentional.
DEFAULT_MONITOR_MAX_KEYS = {
    "inventory_export": 24,
    "disk_trend_monitor": 22,
}


def die(msg: str) -> None:
    print(f"FAIL: {msg}", file=sys.stderr)
    sys.exit(1)


def parse_monitor_limits(raw: str) -> dict[str, int]:
    out: dict[str, int] = {}
    for part in raw.split(","):
        part = part.strip()
        if not part:
            continue
        if "=" not in part:
            die(f"invalid LM_SUMMARY_MONITOR_MAX_KEYS_MAP entry {part!r}; expected monitor=limit")
        name, val = part.split("=", 1)
        name = name.strip()
        val = val.strip()
        if not name or not val.isdigit() or int(val) <= 0:
            die(f"invalid LM_SUMMARY_MONITOR_MAX_KEYS_MAP entry {part!r}; expected monitor=positive_int")
        out[name] = int(val)
    return out


def parse_kv_line(line: str) -> list[tuple[str, str]]:
    tokens = [t for t in line.strip().split(" ") if t]
    out: list[tuple[str, str]] = []
    for t in tokens:
        if "=" not in t:
            die(f"non key=value token: {t!r} in line: {line!r}")
        k, v = t.split("=", 1)
        if not k:
            die(f"empty key in token {t!r} in line: {line!r}")
        out.append((k, v))
    return out


def main() -> None:
    summary = Path(".logs/summary_contract_summary.log")
    if len(sys.argv) > 1:
        summary = Path(sys.argv[1])

    if not summary.exists():
        die(f"missing summary file: {summary} (run tests/summary_contract.sh first)")

    max_keys = int(os.environ.get("LM_SUMMARY_MAX_KEYS", str(DEFAULT_MAX_KEYS)))
    monitor_max_keys = dict(DEFAULT_MONITOR_MAX_KEYS)
    monitor_max_keys.update(parse_monitor_limits(os.environ.get("LM_SUMMARY_MONITOR_MAX_KEYS_MAP", "")))

    lines = [ln.rstrip("\n") for ln in summary.read_text(encoding="utf-8", errors="replace").splitlines()]
    lines = [ln for ln in lines if ln.startswith("monitor=")]

    if not lines:
        die(f"no monitor= lines found in {summary}")

    for idx, line in enumerate(lines, 1):
        if "\t" in line:
            die(f"tab character in summary line {idx}: {line!r}")
        if line != line.strip():
            die(f"leading/trailing whitespace in summary line {idx}: {line!r}")

        kvs = parse_kv_line(line)
        keys = [k for k, _ in kvs]

        seen: set[str] = set()
        dups = []
        for k in keys:
            if k in seen:
                dups.append(k)
            seen.add(k)
        if dups:
            die(f"duplicate keys {sorted(set(dups))} in summary line {idx}: {line!r}")

        missing = REQUIRED - set(keys)
        if missing:
            die(f"missing required keys {sorted(missing)} in summary line {idx}: {line!r}")

        d = dict(kvs)
        if d.get("status") not in VALID_STATUS:
            die(f"invalid status={d.get('status')!r} in summary line {idx}: {line!r}")

        for rk in REQUIRED:
            if d.get(rk, "") == "":
                die(f"empty {rk}= in summary line {idx}: {line!r}")

        if re.search(r'\b\w+="[^"]*\s+[^"]*"', line):
            die(
                "quoted value contains whitespace; values must not contain spaces in summary contract: "
                f"line {idx}: {line!r}"
            )

        monitor = d.get("monitor", "")
        key_limit = monitor_max_keys.get(monitor, max_keys)
        if len(keys) > key_limit:
            die(
                f"summary key budget exceeded for monitor={monitor!r} on line {idx}: "
                f"{len(keys)} keys > limit {key_limit}"
            )

    print("summary parse safety ok")


if __name__ == "__main__":
    main()
