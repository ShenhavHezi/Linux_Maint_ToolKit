#!/usr/bin/env bash
# Monitor catalog and summary-lint helpers for linux-maint.

linux_maint_cmd_list_monitors() {
  local LIST_JSON=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json) LIST_JSON=1; shift 1;;
      -h|--help)
        command_usage list-monitors
        exit 0;;
      *) echo "Unknown list-monitors flag: $1" >&2; exit 2;;
    esac
  done
  local avail monitors_dir
  avail="$(available_monitors 2>/dev/null || true)"
  if [[ -z "$avail" ]]; then
    echo "ERROR: monitors directory not found" >&2
    exit 1
  fi
  if [[ "$MODE" == "repo" && -d "$REPO_MONITORS" ]]; then
    monitors_dir="$REPO_MONITORS"
  elif [[ -d "$LIBEXEC" ]]; then
    monitors_dir="$LIBEXEC"
  elif [[ -d "$REPO_MONITORS" ]]; then
    monitors_dir="$REPO_MONITORS"
  else
    monitors_dir=""
  fi
  MONITORS_LIST="$avail" MONITORS_DIR="$monitors_dir" python3 - "$LIST_JSON" <<'PY'
import json
import os
import re
import sys

json_mode = sys.argv[1] == "1"
monitors = [l.strip() for l in os.environ.get("MONITORS_LIST", "").splitlines() if l.strip()]
monitors_dir = os.environ.get("MONITORS_DIR", "")

fallback_desc = {
    "preflight_check": "Preflight readiness checks (deps/SSH/config).",
    "config_validate": "Validate config file formats and hygiene.",
    "health_monitor": "Core host health (cpu/mem/disk/load).",
    "filesystem_readonly_monitor": "Detect read-only filesystems.",
    "resource_monitor": "Process resource hotspots (CPU/mem).",
    "inode_monitor": "Inode usage checks.",
    "disk_trend_monitor": "Disk growth trend check.",
    "network_monitor": "Network reachability/latency checks.",
    "service_monitor": "Service status checks.",
    "timer_monitor": "systemd timer status checks.",
    "last_run_age_monitor": "Age of last run (wrapper status).",
    "ntp_drift_monitor": "NTP drift checks.",
    "patch_monitor": "Security updates check.",
    "storage_health_monitor": "Storage health (SMART/bad blocks).",
    "kernel_events_monitor": "Kernel error/oom events scan.",
    "log_spike_monitor": "Log spike detection.",
    "cert_monitor": "Certificate expiry checks.",
    "nfs_mount_monitor": "NFS mount presence/health.",
    "ports_baseline_monitor": "Open ports baseline drift.",
    "config_drift_monitor": "Config drift vs baseline.",
    "user_monitor": "User/sudoers baseline drift.",
    "backup_check": "Backup target freshness checks.",
    "inventory_export": "Inventory snapshot exporter.",
}

optional_map = {
    "network_monitor": True,
    "cert_monitor": True,
    "ports_baseline_monitor": True,
    "config_drift_monitor": True,
    "user_monitor": True,
    "backup_check": True,
}

def parse_description(path: str) -> str:
    try:
        lines = open(path, "r", encoding="utf-8", errors="ignore").read().splitlines()
    except Exception:
        return ""
    for i, line in enumerate(lines[:60]):
        m = re.match(r"^#\s*Description\s*:?\s*(.*)$", line)
        if m:
            desc = m.group(1).strip()
            if desc:
                return desc
            parts = []
            for nxt in lines[i + 1:i + 8]:
                if not nxt.strip().startswith("#"):
                    break
                txt = nxt.lstrip("#").strip()
                if txt:
                    parts.append(txt)
            if parts:
                return " ".join(parts)
    for line in lines[:20]:
        m = re.match(r"^#\s*[^-]+-\s*(.+)$", line)
        if m:
            return m.group(1).strip()
    return ""

def parse_config_files(path: str):
    try:
        text = open(path, "r", encoding="utf-8", errors="ignore").read()
    except Exception:
        return []
    cfg = set()
    for m in re.findall(r"/etc/linux_maint/([A-Za-z0-9_./-]+)", text):
        cfg.add(m.strip().strip("/"))
    for m in re.findall(r"\$\{?LM_CFG_DIR[^}]*\}?/([A-Za-z0-9_./-]+)", text):
        cfg.add(m.strip().strip("/"))
    for m in re.findall(r"\$\{?CFG_DIR\}?/([A-Za-z0-9_./-]+)", text):
        cfg.add(m.strip().strip("/"))
    return sorted(cfg)

rows = []
for m in monitors:
    name = m[:-3] if m.endswith(".sh") else m
    path = os.path.join(monitors_dir, m) if monitors_dir else ""
    desc = parse_description(path) if path and os.path.exists(path) else ""
    cfg = parse_config_files(path) if path and os.path.exists(path) else []
    if not desc:
        desc = fallback_desc.get(name, "(no description)")
    optional = bool(optional_map.get(name, False))
    rows.append({
        "monitor": name,
        "description": desc,
        "config_files": cfg,
        "config_optional": bool(optional),
    })

if json_mode:
    print(json.dumps({"monitors": rows}, indent=2, sort_keys=True))
    raise SystemExit(0)

mon_w = max(len(r["monitor"]) for r in rows) if rows else 7
cfg_w = max(len(",".join(r["config_files"])) for r in rows) if rows else 6
print(f"{'MONITOR':<{mon_w}} {'CONFIG':<{cfg_w}} REQUIRED DESCRIPTION")
for r in rows:
    cfg = ",".join(r["config_files"])
    req = "no" if r["config_optional"] else ("yes" if cfg else "no")
    print(f"{r['monitor']:<{mon_w}} {cfg:<{cfg_w}} {req:<8} {r['description']}")
PY
}

linux_maint_cmd_lint_summary() {
  local summary_path="${1:-}"
  shift || true
  local LINT_JSON=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json) LINT_JSON=1; shift 1;;
      -h|--help)
        command_usage lint-summary
        exit 0;;
      *) echo "Unknown lint-summary flag: $1" >&2; exit 2;;
    esac
  done
  if [[ -z "$summary_path" ]]; then
    command_usage lint-summary >&2
    exit 2
  fi
  if [[ ! -f "$summary_path" ]]; then
    echo "ERROR: summary file not found: $summary_path" >&2
    exit 1
  fi
  REPO_ROOT="$REPO_ROOT" SHARE="$SHARE" python3 - "$summary_path" "$LINT_JSON" <<'PY'
import json
import os
import re
import sys
from collections import defaultdict

path = sys.argv[1]
json_mode = sys.argv[2] == "1"

ALLOWED_STATUSES = {"OK", "WARN", "CRIT", "UNKNOWN", "SKIP"}
REASON_RE = re.compile(r"^[a-z0-9_]+$")

def find_repo_root():
    env_root = os.environ.get("REPO_ROOT")
    if env_root and os.path.exists(env_root):
        return env_root
    return os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

def load_allowed_reasons():
    repo_root = find_repo_root()
    candidates = [
        os.path.join(repo_root, "docs", "REASONS.md"),
        os.path.join(os.environ.get("SHARE", ""), "docs", "REASONS.md"),
        os.path.join(os.environ.get("SHARE", ""), "REASONS.md"),
    ]
    allow_candidates = [
        os.path.join(repo_root, "tests", "reason_token_allowlist.txt"),
    ]
    reasons = set()
    for p in candidates:
        if not p or not os.path.exists(p):
            continue
        try:
            with open(p, "r", encoding="utf-8", errors="ignore") as f:
                for line in f:
                    for m in re.findall(r"`([a-z0-9_]+)`", line):
                        reasons.add(m)
        except Exception:
            pass
        if reasons:
            break

    allow = set()
    for p in allow_candidates:
        if not p or not os.path.exists(p):
            continue
        with open(p, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                allow.add(line)
    return reasons, allow

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

allowed_reasons, allowlist_reasons = load_allowed_reasons()
raw = open(path, "r", encoding="utf-8", errors="ignore").read()
strip = raw.lstrip()
if strip.startswith("{"):
    try:
        obj = json.loads(strip)
    except Exception:
        obj = None
    if isinstance(obj, dict) and ("rows" in obj or "meta" in obj):
        errors = []
        if "schema_version" not in obj:
            errors.append("summary JSON missing schema_version")
        run_id = obj.get("run_id")
        if not isinstance(run_id, str) or not run_id:
            errors.append("summary JSON missing run_id")
        ok = not errors
        if json_mode:
            out = {
                "summary_lint_contract_version": 1,
                "ok": ok,
                "errors": errors,
                "counts": {
                    "malformed": 0,
                    "missing_required": 0,
                    "bad_status": 0,
                    "missing_reason": 0,
                    "bad_reason": 0,
                    "dup_monitor_host": 0,
                    "bad_host": 0,
                    "missing_node": 0,
                },
                "missing_monitor_lines": [],
            }
            print(json.dumps(out, indent=2, sort_keys=True))
            raise SystemExit(0 if ok else 2)
        for e in errors:
            print(f"ERROR: {e}")
        raise SystemExit(0 if ok else 2)

txt = raw.splitlines()

executed = []
monitor_lines = []
run_re = re.compile(r"==== Running monitor: (?:.*/)?([A-Za-z0-9_\-]+)\.sh")

for line in txt:
    m = run_re.search(line)
    if m:
        executed.append(m.group(1))
    if "monitor=" in line:
        m2 = re.search(r"(^|\s)(monitor=[^\n]+)$", line)
        if m2:
            ml = m2.group(2)
            if ml.startswith("monitor= ") or ml.startswith("monitor=lines") or ml.startswith("monitor= lines"):
                continue
            monitor_lines.append(ml)

errors = []
if not monitor_lines:
    errors.append(f"no monitor= lines found in {path}")

rows = []
malformed = 0
for l in monitor_lines:
    row, dup_keys, bad_tokens = parse_kv(l)
    if bad_tokens:
        malformed += 1
        errors.append(f"malformed monitor= line (non key=value tokens): {l}")
    if dup_keys:
        malformed += 1
        errors.append(f"duplicate keys {dup_keys} in monitor= line: {l}")
    rows.append(row)

bad_status = 0
missing_reason = 0
bad_reason = 0
missing_required = 0
dup_monitor_host = 0
bad_host = 0
missing_node = 0
seen_monitor_host = {}

for r in rows:
    st = r.get("status", "")
    if not r.get("monitor") or not r.get("host") or not st:
        missing_required += 1
        errors.append(f"monitor= line missing required keys: {r}")
    if r.get("host") == "all":
        bad_host += 1
        errors.append(f"host=all is not allowed (use host=runner instead): {r}")
    if not r.get("node"):
        missing_node += 1
        errors.append(f"monitor= line missing node=: {r}")
    if st not in ALLOWED_STATUSES:
        bad_status += 1
        errors.append(f"invalid status={st} line={r}")
    if r.get("monitor") and r.get("host"):
        key = (r.get("monitor"), r.get("host"))
        seen_monitor_host[key] = seen_monitor_host.get(key, 0) + 1
        if seen_monitor_host[key] > 1:
            dup_monitor_host += 1
            errors.append(f"duplicate monitor/host entries for {key}")
    reason = r.get("reason", "")
    if st in {"WARN", "CRIT", "UNKNOWN", "SKIP"}:
        if "reason" not in r or reason == "":
            missing_reason += 1
        elif not REASON_RE.match(reason):
            bad_reason += 1
            errors.append(f"invalid reason token={reason!r} line={r}")
        elif allowed_reasons and reason not in allowed_reasons and reason not in allowlist_reasons:
            bad_reason += 1
            errors.append(f"reason token not in docs/REASONS.md allowlist: {reason!r} line={r}")

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
    errors.append("executed monitors missing monitor= output: " + ", ".join(missing_monitor_lines))

if missing_reason:
    errors.append(f"{missing_reason} non-OK monitor= lines are missing reason=")

ok = not errors
if json_mode:
    out = {
        "summary_lint_contract_version": 1,
        "ok": ok,
        "errors": errors,
        "counts": {
            "malformed": malformed,
            "missing_required": missing_required,
            "bad_status": bad_status,
            "missing_reason": missing_reason,
            "bad_reason": bad_reason,
            "dup_monitor_host": dup_monitor_host,
            "bad_host": bad_host,
            "missing_node": missing_node,
        },
        "missing_monitor_lines": missing_monitor_lines,
    }
    print(json.dumps(out, indent=2, sort_keys=True))
    raise SystemExit(0 if ok else 2)

for e in errors:
    print(f"ERROR: {e}")
raise SystemExit(0 if ok else 2)
PY
}
