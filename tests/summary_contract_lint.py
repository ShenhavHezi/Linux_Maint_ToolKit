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
REASON_RE = re.compile(r"^[a-z0-9_]+$")


def parse_kv(line: str):
    parts = line.strip().split()
    d = {}
    dup_keys = []
    bad_tokens = []
    for p in parts:
        if "=" in p:
            k, v = p.split("=", 1)
            if k in d:
                dup_keys.append(k)
            d[k] = v
        else:
            bad_tokens.append(p)
    return d, dup_keys, bad_tokens


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

    rows = []
    malformed = 0
    for l in monitor_lines:
        row, dup_keys, bad_tokens = parse_kv(l)
        if bad_tokens:
            malformed += 1
            print(f"ERROR: malformed monitor= line (non key=value tokens): {l}")
        if dup_keys:
            malformed += 1
            print(f"ERROR: duplicate keys {dup_keys} in monitor= line: {l}")
        rows.append(row)

    bad_status = 0
    missing_reason = 0
    bad_reason = 0
    missing_required = 0
    dup_monitor_host = 0
    seen_monitor_host = {}

    for r in rows:
        st = r.get("status", "")
        if not r.get("monitor") or not r.get("host") or not st:
            missing_required += 1
            print(f"ERROR: monitor= line missing required keys: {r}")
        if st not in ALLOWED_STATUSES:
            bad_status += 1
            print(f"ERROR: invalid status={st} line={r}")
        if r.get("monitor") and r.get("host"):
            key = (r.get("monitor"), r.get("host"))
            seen_monitor_host[key] = seen_monitor_host.get(key, 0) + 1
            if seen_monitor_host[key] > 1:
                dup_monitor_host += 1
                print(f"ERROR: duplicate monitor/host entries for {key}")
        reason = r.get("reason", "")
        if st in {"WARN", "CRIT", "UNKNOWN", "SKIP"}:
            if "reason" not in r or reason == "":
                missing_reason += 1
            elif not REASON_RE.match(reason):
                bad_reason += 1
                print(f"ERROR: invalid reason token={reason!r} line={r}")

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

    if missing_reason:
        print(f"ERROR: {missing_reason} non-OK monitor= lines are missing reason=")

    if bad_status or missing_monitor_lines or missing_required or malformed or missing_reason or bad_reason or dup_monitor_host:
        return 2
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <wrapper_log_or_summary_file>", file=sys.stderr)
        raise SystemExit(2)
    raise SystemExit(main(sys.argv[1]))
