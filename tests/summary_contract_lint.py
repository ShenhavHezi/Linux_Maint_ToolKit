#!/usr/bin/env python3
"""Contract lint for linux-maint summary output.

Validates:
- Each executed monitor emits at least one `monitor=` line.
- status is in allowed set.
- (best-effort) non-OK statuses should include reason=.

Input: wrapper logfile (full_health_monitor_*.log) or a file containing only monitor lines.
"""

import re
import sys
from collections import defaultdict

ALLOWED_STATUSES = {"OK", "WARN", "CRIT", "UNKNOWN", "SKIP"}


def parse_kv(line: str):
    parts = line.strip().split()
    d = {}
    for p in parts:
        if "=" in p:
            k, v = p.split("=", 1)
            d[k] = v
    return d


def main(path: str) -> int:
    txt = open(path, "r", encoding="utf-8", errors="ignore").read().splitlines()

    executed = []
    monitor_lines = []

    # executed monitors are bracket-timestamped lines like:
    # [2026-..] ==== Running monitor: monitors/patch_monitor.sh
    run_re = re.compile(r"==== Running monitor: (?:.*/)?([A-Za-z0-9_\-]+)\.sh")

    for line in txt:
        m = run_re.search(line)
        if m:
            executed.append(m.group(1))
        if "monitor=" in line:
            # accept both raw "monitor=..." and timestamp-prefixed lines
            m2 = re.search(r"(^|\s)(monitor=[^\n]+)$", line)
            if m2:
                ml = m2.group(2)
                # Ignore wrapper headers like "FINAL_STATUS_SUMMARY (monitor= lines only)"
                if ml.startswith("monitor= ") or ml.startswith("monitor=lines") or ml.startswith("monitor= lines"):
                    continue
                monitor_lines.append(ml)
    if not monitor_lines:
        print(f"ERROR: no monitor= lines found in {path}")
        return 2

    rows = [parse_kv(l) for l in monitor_lines]

    bad_status = 0
    missing_reason = 0

    for r in rows:
        st = r.get("status", "")
        if st not in ALLOWED_STATUSES:
            bad_status += 1
            print(f"ERROR: invalid status={st} line={r}")
        if st in {"WARN", "CRIT", "UNKNOWN"} and "reason" not in r:
            missing_reason += 1

    # monitor emission check
    mon_to_lines = defaultdict(int)
    for r in rows:
        mon = r.get("monitor")
        if mon:
            mon_to_lines[mon] += 1

    missing_monitor_lines = []
    for m in executed:
        if mon_to_lines.get(m, 0) == 0:
            missing_monitor_lines.append(m)

    if missing_monitor_lines:
        print("ERROR: executed monitors missing monitor= output:")
        for m in missing_monitor_lines:
            print(f"- {m}")

    # best-effort enforcement: missing_reason is a WARN unless other errors exist
    if missing_reason:
        print(f"WARN: {missing_reason} non-OK monitor= lines are missing reason=")

    if bad_status or missing_monitor_lines:
        return 2
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <wrapper_log_or_summary_file>", file=sys.stderr)
        raise SystemExit(2)
    raise SystemExit(main(sys.argv[1]))
