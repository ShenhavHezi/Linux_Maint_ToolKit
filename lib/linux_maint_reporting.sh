#!/usr/bin/env bash
# Reporting/export command helpers for linux-maint.

linux_maint_reporting_log_dir() {
    linux_maint_effective_log_dir
}

linux_maint_reporting_status_file() {
    linux_maint_effective_status_file
}

linux_maint_reporting_summary_latest() {
    linux_maint_effective_summary_latest
}

linux_maint_reporting_summary_dir() {
    linux_maint_effective_summary_dir
}

linux_maint_reporting_summary_json_latest() {
    linux_maint_effective_summary_json_latest
}

linux_maint_reporting_latest_log() {
    linux_maint_effective_latest_log
}

linux_maint_reporting_status_file_state() {
    local path="$1"
    local -a missing=()
    local key
    if [[ -z "$path" || ! -e "$path" ]]; then
      printf 'missing\n'
      return 0
    fi
    if [[ ! -r "$path" ]]; then
      printf 'unreadable\n'
      return 0
    fi
    for key in overall exit_code timestamp run_id; do
      if ! grep -q "^${key}=" "$path" 2>/dev/null; then
        missing+=("$key")
      fi
    done
    if [[ "${#missing[@]}" -gt 0 ]]; then
      printf 'malformed:%s\n' "$(IFS=,; echo "${missing[*]}")"
      return 0
    fi
    printf 'ok\n'
}

linux_maint_reporting_summary_history_file_state() {
    local path="$1"
    local detail
    if [[ -z "$path" || ! -e "$path" ]]; then
      printf 'missing\n'
      return 0
    fi
    if [[ ! -r "$path" ]]; then
      printf 'unreadable\n'
      return 0
    fi
    if detail="$(python3 - "$path" <<'PY'
import sys

path = sys.argv[1]
allowed = {"OK", "WARN", "CRIT", "UNKNOWN", "SKIP"}
had = False
try:
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            line = line.strip()
            if not line.startswith("monitor="):
                continue
            had = True
            row = {}
            for tok in line.split():
                if "=" not in tok:
                    print("bad_token")
                    raise SystemExit(1)
                key, val = tok.split("=", 1)
                row[key] = val
            missing = [k for k in ("monitor", "host", "status") if k not in row]
            if missing:
                print("missing_" + "_".join(missing))
                raise SystemExit(1)
            if row["status"] not in allowed:
                print("invalid_status")
                raise SystemExit(1)
except Exception:
    print("unreadable")
    raise SystemExit(2)
if not had:
    print("no_monitor_lines")
    raise SystemExit(1)
print("ok")
PY
)"; then
      printf 'ok\n'
      return 0
    fi
    if [[ "$detail" == "unreadable" ]]; then
      printf 'unreadable\n'
      return 0
    fi
    printf 'malformed:%s\n' "$detail"
}

linux_maint_cmd_diff() {
    local JSON=0
    local DIFF_COLOR=1
    local DIFF_STATE_DIR SUMMARY_LATEST PREV_SUMMARY CUR_SUMMARY diff_tool
    if [[ "${1:-}" == "--json" ]]; then
      JSON=1
      shift
    fi
    [[ -n "${NO_COLOR:-}" || -n "${LM_NO_COLOR:-}" ]] && DIFF_COLOR=0
    color_enabled || DIFF_COLOR=0

    DIFF_STATE_DIR="$(linux_maint_effective_notify_state_dir)"
    SUMMARY_LATEST="$(linux_maint_reporting_summary_latest)"
    PREV_SUMMARY="$DIFF_STATE_DIR/last_summary_monitor_lines.log"
    CUR_SUMMARY="$SUMMARY_LATEST"

    if [[ "$JSON" -eq 0 ]]; then
      if [[ -t 1 ]]; then
        section "linux-maint diff"
      fi
      echo "diff_state_dir=$DIFF_STATE_DIR"
    fi

    if [[ ! -f "$CUR_SUMMARY" ]]; then
      echo "No current summary file: $CUR_SUMMARY" >&2
      echo "Run linux-maint run first." >&2
      exit 1
    fi
    if [[ ! -f "$PREV_SUMMARY" ]]; then
      echo "No previous diff state file: $PREV_SUMMARY" >&2
      echo "The wrapper writes this after each run (best-effort). Typically you need to run linux-maint run twice to get a useful diff." >&2
      exit 1
    fi

    if [[ "$MODE" == "repo" ]]; then
      diff_tool="$REPO_ROOT/tools/summary_diff.py"
    else
      diff_tool="$LIBEXEC/summary_diff.py"
    fi
    if [[ ! -x "$diff_tool" ]]; then
      echo "Diff tool not found/executable: $diff_tool" >&2
      hint_line "reinstall linux-maint to include summary_diff.py" >&2
      exit 1
    fi

    if [[ "$JSON" -eq 1 ]]; then
      exec python3 "$diff_tool" "$PREV_SUMMARY" "$CUR_SUMMARY" --json
    else
      LM_COLOR="$DIFF_COLOR" exec python3 "$diff_tool" "$PREV_SUMMARY" "$CUR_SUMMARY"
    fi
}

linux_maint_cmd_logs() {
    local n="${1:-200}"
    local latest_log
    latest_log="$(linux_maint_reporting_latest_log)"
    if [[ ! -f "$latest_log" ]]; then
      if [[ "$MODE" == "repo" ]]; then
        echo "No repo log yet: $latest_log"
        echo "Hint: run linux-maint run to generate a wrapper log" >&2
      else
        echo "No installed log yet: $latest_log"
        echo "Hint: run sudo linux-maint run to generate a wrapper log" >&2
      fi
      exit 1
    fi
    if [[ -t 1 ]]; then
      section "logs (last $n)"
      echo "file=$latest_log"
    fi
    if [[ ! -r "$latest_log" ]]; then
      echo "Unreadable log file: $latest_log" >&2
      echo "Hint: fix permissions or rerun with sudo if this is an installed-mode log" >&2
      exit 1
    fi
    exec tail -n "$n" "$latest_log"
}

linux_maint_cmd_report() {
    REPORT_JSON=0
    REPORT_COLOR=1
    REPORT_COMPACT=0
    REPORT_SHORT=0
    REPORT_TABLE="${LM_REPORT_TABLE:-0}"
    REPORT_NO_TREND=0
    REPORT_NO_SLOW=0
    REPORT_NO_REASONS=0
    REPORT_NO_PROBLEMS=0
    REPORT_REDACT=0
    OUTPUT_PATH=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --json) REPORT_JSON=1; shift 1;;
        --no-color) REPORT_COLOR=0; shift 1;;
        --compact) REPORT_COMPACT=1; shift 1;;
        --short) REPORT_SHORT=1; shift 1;;
        --table) REPORT_TABLE=1; shift 1;;
        --redact) REPORT_REDACT=1; shift 1;;
        --no-redact) REPORT_REDACT=0; shift 1;;
        --no-trend) REPORT_NO_TREND=1; shift 1;;
        --no-slow) REPORT_NO_SLOW=1; shift 1;;
        --no-reasons) REPORT_NO_REASONS=1; shift 1;;
        --no-problems) REPORT_NO_PROBLEMS=1; shift 1;;
        --output) OUTPUT_PATH="$2"; shift 2;;
        -h|--help)
          command_usage report
          exit 0;;
        *) echo "Unknown report flag: $1" >&2; exit 2;;
      esac
    done
    [[ -n "${NO_COLOR:-}" || -n "${LM_NO_COLOR:-}" ]] && REPORT_COLOR=0
    color_enabled || REPORT_COLOR=0
    if [[ "$REPORT_JSON" -eq 1 && "$REPORT_REDACT" -eq 1 ]]; then
      echo "ERROR: --redact is only for human output (not --json)" >&2
      exit 2
    fi

    if [[ -n "$OUTPUT_PATH" ]]; then
      if ! atomic_output_begin "$OUTPUT_PATH"; then
        echo "ERROR: unable to write output to $OUTPUT_PATH" >&2
        exit 2
      fi
      trap atomic_output_end EXIT
    fi

    status_file="$(linux_maint_reporting_status_file)"
    summary_json_file="$(linux_maint_reporting_summary_json_latest)"

    tmp_status="$(mktemp -p "$TMPDIR" linux_maint_report_status.XXXXXX.json)"
    tmp_trend="$(mktemp -p "$TMPDIR" linux_maint_report_trend.XXXXXX.json)"
    tmp_runtimes="$(mktemp -p "$TMPDIR" linux_maint_report_runtimes.XXXXXX.json)"

    status_rc=0
    "$0" status --json --problems 20 --reasons 10 >"$tmp_status" 2>/dev/null || status_rc=$?
    "$0" trend --last 10 --json >"$tmp_trend" 2>/dev/null || printf '{}' >"$tmp_trend"
    "$0" runtimes --last 1 --json >"$tmp_runtimes" 2>/dev/null || printf '{}' >"$tmp_runtimes"

    REPORT_EXPECTED_SKIPS=""
    if [[ "$REPORT_JSON" -eq 0 ]]; then
      cfg_dir="$(linux_maint_effective_cfg_dir)"
      if banner="$(expected_skips_text "$cfg_dir")"; then
        REPORT_EXPECTED_SKIPS="$banner"
      fi
    fi

    LM_COLOR="$REPORT_COLOR" REPORT_COMPACT="$REPORT_COMPACT" REPORT_SHORT="$REPORT_SHORT" REPORT_TABLE="$REPORT_TABLE" REPORT_NO_TREND="$REPORT_NO_TREND" REPORT_NO_SLOW="$REPORT_NO_SLOW" REPORT_NO_REASONS="$REPORT_NO_REASONS" REPORT_NO_PROBLEMS="$REPORT_NO_PROBLEMS" REPORT_EXPECTED_SKIPS="$REPORT_EXPECTED_SKIPS" REPORT_REDACT="$REPORT_REDACT" REPORT_STATUS_RC="$status_rc" REPORT_SUMMARY_JSON="$summary_json_file" python3 - "$tmp_status" "$tmp_trend" "$tmp_runtimes" "$REPORT_JSON" <<'PY'
import json, os, sys, re
import re
import builtins

status_path, trend_path, runtimes_path, json_mode = sys.argv[1:5]
json_mode = json_mode == "1"
status_rc = int(os.environ.get("REPORT_STATUS_RC", "0"))
color = os.environ.get("LM_COLOR","1") == "1"
compact = os.environ.get("REPORT_COMPACT","0") == "1"
short = os.environ.get("REPORT_SHORT","0") == "1"
table = os.environ.get("REPORT_TABLE","0") == "1"
no_trend = os.environ.get("REPORT_NO_TREND","0") == "1"
no_slow = os.environ.get("REPORT_NO_SLOW","0") == "1"
no_reasons = os.environ.get("REPORT_NO_REASONS","0") == "1"
no_problems = os.environ.get("REPORT_NO_PROBLEMS","0") == "1"
expected_skips = os.environ.get("REPORT_EXPECTED_SKIPS","").strip()
redact = os.environ.get("REPORT_REDACT","0") == "1"
redact_json = os.environ.get("LM_REDACT_JSON","0") in ("1","true","TRUE","yes","YES")
redact_json_strict = os.environ.get("LM_REDACT_JSON_STRICT","0") in ("1","true","TRUE","yes","YES")
summary_json_path = os.environ.get("REPORT_SUMMARY_JSON","")

def redact_line(s: str) -> str:
    pats = [
        (re.compile(r'(?i)\\b([A-Za-z0-9_]*(password|passwd|token|api[_-]?key|secret|access[_-]?key|private[_-]?key|session([_-]?id)?|id[_-]?token|refresh[_-]?token|x[_-]?auth[_-]?token)[A-Za-z0-9_]*)=([^ \\t]+)'), r'\\1=REDACTED'),
        (re.compile(r'(?i)\\b(Authorization:|X-Auth-Token:)\\s+[^ \\t]+'), r'\\1 REDACTED'),
        (re.compile(r'(?i)\\b(Bearer)\\s+[A-Za-z0-9_.~+/-]+=*'), r'\\1 REDACTED'),
        (re.compile(r'\\b[0-9A-Za-z_-]{12,}\\.[0-9A-Za-z_-]{12,}\\.[0-9A-Za-z_-]{12,}\\b'), 'REDACTED_JWT'),
        (re.compile(r'\\bAKIA[0-9A-Z]{16}\\b'), 'AKIA_REDACTED'),
        (re.compile(r'\\bASIA[0-9A-Z]{16}\\b'), 'ASIA_REDACTED'),
        (re.compile(r'\\bgh[pousr]_[A-Za-z0-9]{20,}\\b'), 'GH_REDACTED'),
        (re.compile(r'\\bgithub_pat_[A-Za-z0-9_]{20,}\\b'), 'GH_PAT_REDACTED'),
        (re.compile(r'\\bxox[baprs]-[A-Za-z0-9-]{10,}\\b'), 'SLACK_REDACTED'),
        (re.compile(r'\\bAIza[0-9A-Za-z_-]{35}\\b'), 'GCP_REDACTED'),
        (re.compile(r'\\bya29\\.[A-Za-z0-9_-]{10,}\\b'), 'OAUTH_REDACTED'),
        (re.compile(r'-----BEGIN [A-Z ]*PRIVATE KEY-----'), '-----BEGIN PRIVATE KEY-----'),
        (re.compile(r'-----END [A-Z ]*PRIVATE KEY-----'), '-----END PRIVATE KEY-----'),
    ]
    out = s
    for pat, rep in pats:
        out = pat.sub(rep, out)
    return out

def redact_json_obj(obj):
    if isinstance(obj, dict):
        return {k: redact_json_obj(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [redact_json_obj(v) for v in obj]
    if isinstance(obj, str):
        if redact_json_strict:
            return "REDACTED"
        return redact_line(obj)
    return obj

if redact and not json_mode:
    def print(*args, **kwargs):
        sep = kwargs.get("sep", " ")
        end = kwargs.get("end", "\\n")
        text = sep.join(str(a) for a in args)
        builtins.print(redact_line(text), end=end)

def c(s, code):
    if not color:
        return s
    return f"\033[{code}m{s}\033[0m"

def header(text):
    if not color:
        return text
    if text.startswith("=== ") and text.endswith(" ==="):
        inner = text[4:-4]
        return f"=== {c(inner, '1;36')} ==="
    return c(text, "1;36")

def section(title):
    # Friendly section header for human output.
    print("")
    print(c(title, "1;36"))

def color_status(st, text=None):
    label = text if text is not None else st
    if st == "CRIT":
        return c(label, "1;31")
    if st == "WARN":
        return c(label, "1;33")
    if st == "OK":
        return c(label, "1;32")
    if st == "UNKNOWN":
        return c(label, "1;35")
    if st == "SKIP":
        return c(label, "1;36")
    return label

def final_label(cmd, result):
    mapping = {
        "OK": ("1;32", "ok"),
        "WARN": ("1;33", "warn"),
        "CRIT": ("1;31", "crit"),
        "UNKNOWN": ("1;33", "unknown"),
        "SKIP": ("1;36", "skip"),
    }
    code, word = mapping.get(result, ("1;33", str(result).lower()))
    return c(f"{cmd} {word}", code)

def read_json(p):
    try:
        with open(p, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}

status = read_json(status_path)
trend = read_json(trend_path)
runtimes = read_json(runtimes_path)
summary_json_doc = read_json(summary_json_path) if summary_json_path else {}
privilege = summary_json_doc.get("privilege", {}) if isinstance(summary_json_doc, dict) else {}
if not isinstance(privilege, dict):
    privilege = {}

if status_rc != 0:
    print("ERROR: report requires a successful status --json snapshot", file=sys.stderr)
    raise SystemExit(2)
if not isinstance(status, dict) or "last_status" not in status or "totals" not in status:
    print("ERROR: report requires valid JSON from status --json", file=sys.stderr)
    raise SystemExit(2)
if status.get("last_status_state") in ("unreadable", "malformed"):
    print("ERROR: report requires readable last_status_full metadata from status --json", file=sys.stderr)
    raise SystemExit(2)

if json_mode:
    run_id = ""
    if isinstance(status, dict):
        run_id = status.get("run_id") or (status.get("last_status", {}) or {}).get("run_id", "")
    out = {
        "schema_version": 1,
        "run_id": run_id,
        "report_json_contract_version": 1,
        "status": status,
        "trend": trend,
        "runtimes": runtimes,
        "privilege": privilege,
    }
    if redact_json or redact_json_strict:
        out = redact_json_obj(out)
    print(json.dumps(out, indent=2, sort_keys=True))
    raise SystemExit(0)

mode = status.get("mode", "unknown")
last = status.get("last_status", {})
overall = last.get("overall", "UNKNOWN")
exit_code = last.get("exit_code", "3")
logfile = last.get("logfile", "")
summary = status.get("summary_file", "")
baseline = status.get("baseline", {}) if isinstance(status, dict) else {}
baseline_summary = baseline.get("summary", {}) if isinstance(baseline, dict) else {}
baseline_result = baseline.get("result") if isinstance(baseline, dict) else None
baseline_attention = len((baseline.get("attention_items") or [])) if isinstance(baseline, dict) else 0
priv_summary = privilege.get("summary", {}) if isinstance(privilege, dict) else {}
priv_monitors = privilege.get("monitors", []) if isinstance(privilege, dict) else []
if not isinstance(priv_summary, dict):
    priv_summary = {}
if not isinstance(priv_monitors, list):
    priv_monitors = []
ov = color_status(overall)
if short:
    print(header("=== linux-maint report (short) ==="))
    print(f"mode={mode} overall={ov} exit_code={exit_code}")
    if expected_skips:
        print(expected_skips)
    totals = status.get("totals", {})
    if totals:
        parts = []
        for k in ["CRIT","WARN","UNKNOWN","SKIP","OK"]:
            v = totals.get(k,0)
            kv = f"{k}={v}"
            if v != 0:
                kv = color_status(k, kv)
            parts.append(kv)
        print("totals: " + " ".join(parts))
    problems = status.get("problems", [])
    if problems and not no_problems:
        print("\nproblems (top 5):")
        for p in problems[:5]:
            s = p.get("status","UNKNOWN")
            mon = p.get("monitor","unknown")
            host = p.get("host","")
            reason = p.get("reason","")
            st = color_status(s)
            line = f"{st} {mon}"
            if host:
                line += f" host={host}"
            if reason:
                line += f" reason={reason}"
            print(line)
    else:
        print("\nproblems: none (all OK)")
    if isinstance(baseline, dict) and baseline_summary:
        print(
            "\nbaseline: result={} stale_items={} drift_items={} missing_inputs={} changed_hosts_total={}".format(
                baseline_result or "WARN",
                int(baseline_summary.get("stale_items", 0) or 0),
                int(baseline_summary.get("drift_items", 0) or 0),
                int(baseline_summary.get("missing_inputs", 0) or 0),
                int(baseline_summary.get("changed_hosts_total", 0) or 0),
            )
        )
    if priv_summary:
        print(
            "\nprivilege: monitors={} ok={} violations={} not_configured={} invalid_policy={}".format(
                int(priv_summary.get("total", 0) or 0),
                int(priv_summary.get("ok", 0) or 0),
                int(priv_summary.get("violations", 0) or 0),
                int(priv_summary.get("not_configured", 0) or 0),
                int(priv_summary.get("invalid_policy", 0) or 0),
            )
        )
    guidance = []
    if overall != "OK":
        guidance.extend(["linux-maint doctor", "linux-maint status --verbose"])
    else:
        guidance.append("linux-maint run")
    if baseline_result and baseline_result != "OK":
        guidance.append("linux-maint baseline refresh --plan")
    if int(priv_summary.get("violations", 0) or 0) or int(priv_summary.get("invalid_policy", 0) or 0):
        guidance.append("linux-maint run --plan")
    print("\n== Guidance ==")
    seen = set()
    for step in guidance:
        if step in seen:
            continue
        seen.add(step)
        print(f"next_step: {step}")
    print("\n== Summary ==")
    print(f"overall={overall}")
    print(f"exit_code={exit_code}")
    print(f"problems={len(problems)}")
    print("history_warnings=0")
    if baseline_result:
        print(f"baseline_result={baseline_result}")
        print(f"baseline_attention={baseline_attention}")
    print(f"result={overall}")
    print(final_label("report", overall))
    raise SystemExit(0)
if not compact:
    banner = f"health={color_status(overall)} exit_code={exit_code}"
    print(header("=== linux-maint report ===") + " " + banner)
print(f"mode={mode} overall={ov} exit_code={exit_code}")
if expected_skips and not compact:
    print(expected_skips)
if not compact:
    section("files")
    if logfile:
        print(f"logfile={logfile}")
    if summary:
        print(f"summary_file={summary}")

totals = status.get("totals", {})
if totals:
    if not compact:
        section("totals")
    tvals=[("CRIT", totals.get("CRIT",0)), ("WARN", totals.get("WARN",0)), ("UNKNOWN", totals.get("UNKNOWN",0)), ("SKIP", totals.get("SKIP",0)), ("OK", totals.get("OK",0))]
    maxk=max(len(k) for k,_ in tvals) if tvals else 0
    maxv=max(len(str(v)) for _,v in tvals) if tvals else 0
    if table:
        print("totals:")
        print(f"  {'STATUS':<{maxk}} {'COUNT':<{maxv}}")
        for k,v in tvals:
            label = f"{k:<{maxk}}"
            count = f"{str(v):<{maxv}}"
            label = color_status(k, label)
            if v != 0:
                count = color_status(k, count)
            print(f"  {label} {count}")
    else:
        parts = []
        for k, v in tvals:
            kv = f"{k}={v}"
            if v != 0:
                kv = color_status(k, kv)
            parts.append(kv)
        line = "totals: " + " ".join(parts)
        print(line)
    if compact:
        raise SystemExit(0)

if priv_summary:
    section("privilege policy")
    print(
        "monitors={} ok={} violations={} not_configured={} invalid_policy={} policy_file={}".format(
            int(priv_summary.get("total", 0) or 0),
            int(priv_summary.get("ok", 0) or 0),
            int(priv_summary.get("violations", 0) or 0),
            int(priv_summary.get("not_configured", 0) or 0),
            int(priv_summary.get("invalid_policy", 0) or 0),
            privilege.get("policy_file") or "none",
        )
    )
    attention = [
        m for m in priv_monitors
        if isinstance(m, dict) and m.get("result") in ("violation", "invalid_policy")
    ]
    for m in attention[:10]:
        print(
            "attention monitor={} policy={} result={} euid={}".format(
                m.get("monitor", ""),
                m.get("policy", ""),
                m.get("result", ""),
                m.get("euid", ""),
            )
        )

problems = status.get("problems", [])
if problems and not no_problems:
    section("problems (top)")
    if table:
        rows=[]
        for p in problems[:20]:
            s=p.get("status","UNKNOWN")
            mon=p.get("monitor","unknown")
            host=p.get("host","")
            reason=p.get("reason","")
            rows.append((s, mon, host, reason))
        sev_order={'CRIT':0,'WARN':1,'UNKNOWN':2,'SKIP':3}
        rows.sort(key=lambda r: sev_order.get(r[0], 9))
        headers=("STATUS","MONITOR","HOST","REASON")
        w=[len(h) for h in headers]
        for r in rows:
            for i,v in enumerate(r):
                w[i]=max(w[i], len(str(v)))
        print(f"{headers[0]:<{w[0]}} {headers[1]:<{w[1]}} {headers[2]:<{w[2]}} {headers[3]}")
        for s,mon,host,reason in rows:
            s_pad=f"{s:<{w[0]}}"
            if s=="CRIT":
                s_pad=c(s_pad,'1;31')
            elif s=="WARN":
                s_pad=c(s_pad,'1;33')
            elif s=="OK":
                s_pad=c(s_pad,'1;32')
            elif s=="UNKNOWN":
                s_pad=c(s_pad,'1;35')
            elif s=="SKIP":
                s_pad=c(s_pad,'1;36')
            print(f"{s_pad} {mon:<{w[1]}} {host:<{w[2]}} {reason}")
    else:
        for p in problems[:20]:
            s = p.get("status","UNKNOWN")
            mon = p.get("monitor","unknown")
            host = p.get("host","")
            reason = p.get("reason","")
            st = color_status(s)
            line = f"{st} {mon}"
            if host:
                line += f" host={host}"
            if reason:
                line += f" reason={reason}"
            print(line)
    print(c("\nnext_steps:", "1;36"))
    print("  - run: linux-maint doctor")
    print("  - run: linux-maint status --verbose")
elif not no_problems:
    if table:
        section("problems (top)")
        print("STATUS MONITOR HOST REASON")
    print("\nproblems: none (all OK)")

reason_rollup = status.get("reason_rollup", [])
if reason_rollup and not no_reasons:
    section("reasons (latest)")
    for r in reason_rollup[:10]:
        print(f"{r.get('reason')}={r.get('count')}")

    hints_map = {
        "permission_denied": "Run with sudo or fix permissions for logs/state/config.",
        "missing_optional_cmd": "Install the optional dependency listed in the monitor output.",
        "missing_dependency": "Install the required dependency on the runner/host.",
        "kernel_log_unreadable": "Check journal/dmesg permissions and ensure kernel logs are readable.",
        "collect_failed": "Inventory export failed; verify /var/log/inventory and required tools (ip, lsblk, lscpu).",
        "ports_baseline_changed": "Review listening port changes and update the baseline if expected.",
        "config_drift_changed": "Review config changes and update the baseline if intended.",
        "user_anomalies": "Review new/removed users and sudoers changes.",
        "ntp_drift_high": "Check NTP/chrony sync and clock drift.",
        "ntp_not_synced": "Check NTP/chrony sync.",
        "missing_log_source": "Ensure journald/syslog is available and readable.",
        "security_updates_pending": "Apply security updates via your package manager.",
        "updates_pending": "Apply pending package updates.",
        "baseline_missing": "Create a baseline via linux-maint baseline.",
        "baseline_created": "Baseline created; rerun to compare changes.",
        "baseline_updated": "Baseline updated; rerun to check for drift.",
        "baseline_exists": "Baseline already exists; use --update if you want to overwrite it.",
        "baseline_collect_failed": "Baseline collection failed; check permissions/SSH and retry.",
        "timer_missing": "Install/enable linux-maint.timer if you want scheduled runs.",
        "timer_disabled": "Enable linux-maint.timer (systemctl enable --now linux-maint.timer).",
        "timer_inactive": "Start linux-maint.timer (systemctl start linux-maint.timer).",
        "ssh_unreachable": "Verify SSH connectivity and credentials for the target host.",
        "stale_run": "Check timers/cron; last run appears too old.",
    }
    reasons = [r.get("reason") for r in reason_rollup[:10] if r.get("reason")]
    hint_lines = []
    seen = set()
    for reason in reasons:
        if reason in hints_map and reason not in seen:
            seen.add(reason)
            hint_lines.append(f"{reason}: {hints_map[reason]}")
    if hint_lines:
        print(c("\nhints:", "1;36"))
        for h in hint_lines[:5]:
            print(f"- {h}")

if isinstance(baseline, dict) and baseline_summary:
    section("baseline lifecycle")
    print(
        "result={} stale_items={} fresh_items={} drift_items={} missing_inputs={} changed_hosts_total={}".format(
            baseline_result or "WARN",
            int(baseline_summary.get("stale_items", 0) or 0),
            int(baseline_summary.get("fresh_items", 0) or 0),
            int(baseline_summary.get("drift_items", 0) or 0),
            int(baseline_summary.get("missing_inputs", 0) or 0),
            int(baseline_summary.get("changed_hosts_total", 0) or 0),
        )
    )
    if baseline_attention:
        print(f"attention_items={baseline_attention}")
    baseline_next_steps = baseline.get("next_steps") or []
    if baseline_next_steps:
        print(f"next_step_hint={baseline_next_steps[0]}")

if trend and not no_trend:
    t_totals = trend.get("totals", {})
    if t_totals:
        section("trend (last runs)")
        print("totals: " + " ".join(f"{k}={t_totals.get(k,0)}" for k in ["CRIT","WARN","UNKNOWN","SKIP","OK"]))
    t_reasons = trend.get("reasons", [])
    if t_reasons:
        print("top_reasons:")
        for r in t_reasons[:10]:
            print(f"{r.get('reason')}={r.get('count')}")
    t_warnings = trend.get("history_warnings", [])
    if t_warnings:
        print("history_warnings:")
        for warn in t_warnings[:10]:
            if isinstance(warn, dict):
                detail = warn.get("detail")
                msg = f"- skipped {warn.get('state','unknown')} history file: {warn.get('file','')}"
                if detail:
                    msg += f" ({detail})"
                print(msg)
            else:
                print(f"- {warn}")

rows = runtimes.get("rows", [])
if rows and not no_slow:
    section("slow monitors (last run)")
    if table:
        rows2=[(r.get("monitor",""), str(r.get("ms",""))) for r in rows[:10]]
        headers=("MONITOR","MS")
        w=[len(h) for h in headers]
        for r in rows2:
            for i,v in enumerate(r):
                w[i]=max(w[i], len(str(v)))
        print(f"{headers[0]:<{w[0]}} {headers[1]:<{w[1]}}")
        for mon,ms in rows2:
            print(f"{mon:<{w[0]}} {ms:<{w[1]}}")
    else:
        for r in rows[:10]:
            print(f"{r.get('monitor')} ms={r.get('ms')}")
history_warning_count = 0
if isinstance(trend, dict):
    history_warning_count = len(trend.get("history_warnings", []) or [])
guidance = []
if overall != "OK":
    guidance.extend(["linux-maint doctor", "linux-maint status --verbose"])
else:
    guidance.append("linux-maint run")
if history_warning_count:
    guidance.append("linux-maint status --since 1d")
if rows and overall != "OK":
    guidance.append("linux-maint runtimes --last 5")
if baseline_result and baseline_result != "OK":
    guidance.append("linux-maint baseline refresh --plan")
if int(priv_summary.get("violations", 0) or 0) or int(priv_summary.get("invalid_policy", 0) or 0):
    guidance.append("linux-maint run --plan")
print("\n== Guidance ==")
seen = set()
for step in guidance:
    if step in seen:
        continue
    seen.add(step)
    print(f"next_step: {step}")
print("\n== Summary ==")
print(f"overall={overall}")
print(f"exit_code={exit_code}")
print(f"problems={len(problems)}")
print(f"history_warnings={history_warning_count}")
if baseline_result:
    print(f"baseline_result={baseline_result}")
    print(f"baseline_attention={baseline_attention}")
print(f"result={overall}")
print(final_label("report", overall))
PY

    rm -f "$tmp_status" "$tmp_trend" "$tmp_runtimes" 2>/dev/null || true
}

linux_maint_cmd_metrics() {
    METRICS_JSON=0
    METRICS_PROM=0
    METRICS_OUT=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --json) METRICS_JSON=1; shift 1;;
        --prom) METRICS_PROM=1; shift 1;;
        --output) METRICS_OUT="$2"; shift 2;;
        -h|--help)
          command_usage metrics
          exit 0;;
        *) echo "Unknown metrics flag: $1" >&2; exit 2;;
      esac
    done

    if [[ "$METRICS_JSON" -eq 1 && "$METRICS_PROM" -eq 1 ]]; then
      echo "ERROR: choose only one output format (--json or --prom)" >&2
      exit 2
    fi
    if [[ "$METRICS_PROM" -eq 1 ]]; then
      if [[ -n "$METRICS_OUT" ]]; then
        "$0" status --prom --output "$METRICS_OUT"
      else
        "$0" status --prom
      fi
      exit 0
    fi
    if [[ "$METRICS_JSON" -ne 1 ]]; then
      echo "ERROR: metrics output is JSON-only (use --json) or --prom" >&2
      echo "Hint: use linux-maint report or linux-maint status for human-readable output" >&2
      exit 2
    fi

    tmp_status="$(mktemp -p "$TMPDIR" linux_maint_metrics_status.XXXXXX.json)"
    tmp_trend="$(mktemp -p "$TMPDIR" linux_maint_metrics_trend.XXXXXX.json)"
    tmp_runtimes="$(mktemp -p "$TMPDIR" linux_maint_metrics_runtimes.XXXXXX.json)"

    status_rc=0
    "$0" status --json --problems 20 --reasons 10 >"$tmp_status" 2>/dev/null || status_rc=$?
    "$0" trend --last 10 --json >"$tmp_trend" 2>/dev/null || printf '{}' >"$tmp_trend"
    "$0" runtimes --last 1 --json >"$tmp_runtimes" 2>/dev/null || printf '{}' >"$tmp_runtimes"

    METRICS_STATUS_RC="$status_rc" python3 - "$tmp_status" "$tmp_trend" "$tmp_runtimes" <<'PY'
import json, os, sys, re

status_path, trend_path, runtimes_path = sys.argv[1:4]
status_rc = int(os.environ.get("METRICS_STATUS_RC", "0"))
redact_json = os.environ.get("LM_REDACT_JSON","0") in ("1","true","TRUE","yes","YES")
redact_json_strict = os.environ.get("LM_REDACT_JSON_STRICT","0") in ("1","true","TRUE","yes","YES")

def read_json(p):
    try:
        with open(p, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}

def redact_line(s: str) -> str:
    pats = [
        (re.compile(r'(?i)\b([A-Za-z0-9_]*(password|passwd|token|api[_-]?key|secret|access[_-]?key|private[_-]?key|session([_-]?id)?|id[_-]?token|refresh[_-]?token|x[_-]?auth[_-]?token)[A-Za-z0-9_]*)=([^ \t]+)'), r'\1=REDACTED'),
        (re.compile(r'(?i)\b(Authorization:|X-Auth-Token:)\s+[^ \t]+'), r'\1 REDACTED'),
        (re.compile(r'(?i)\b(Bearer)\s+[A-Za-z0-9_.~+/-]+=*'), r'\1 REDACTED'),
        (re.compile(r'\b[0-9A-Za-z_-]{12,}\.[0-9A-Za-z_-]{12,}\.[0-9A-Za-z_-]{12,}\b'), 'REDACTED_JWT'),
        (re.compile(r'\bAKIA[0-9A-Z]{16}\b'), 'AKIA_REDACTED'),
        (re.compile(r'\bASIA[0-9A-Z]{16}\b'), 'ASIA_REDACTED'),
        (re.compile(r'\bgh[pousr]_[A-Za-z0-9]{20,}\b'), 'GH_REDACTED'),
        (re.compile(r'\bgithub_pat_[A-Za-z0-9_]{20,}\b'), 'GH_PAT_REDACTED'),
        (re.compile(r'\bxox[baprs]-[A-Za-z0-9-]{10,}\b'), 'SLACK_REDACTED'),
        (re.compile(r'\bAIza[0-9A-Za-z_-]{35}\b'), 'GCP_REDACTED'),
        (re.compile(r'\bya29\.[A-Za-z0-9_-]{10,}\b'), 'OAUTH_REDACTED'),
        (re.compile(r'-----BEGIN [A-Z ]*PRIVATE KEY-----'), '-----BEGIN PRIVATE KEY-----'),
        (re.compile(r'-----END [A-Z ]*PRIVATE KEY-----'), '-----END PRIVATE KEY-----'),
    ]
    out = s
    for pat, rep in pats:
        out = pat.sub(rep, out)
    return out

def redact_json_obj(obj):
    if isinstance(obj, dict):
        return {k: redact_json_obj(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [redact_json_obj(v) for v in obj]
    if isinstance(obj, str):
        if redact_json_strict:
            return "REDACTED"
        return redact_line(obj)
    return obj

def parse_kv_line(line: str):
    d = {}
    for p in line.strip().split():
        if "=" in p:
            k, v = p.split("=", 1)
            d[k] = v
    return d

def read_summary_rows(summary_path):
    rows = []
    if summary_path and os.path.exists(summary_path):
        try:
            with open(summary_path, "r", encoding="utf-8", errors="ignore") as f:
                for line in f:
                    if line.startswith("monitor="):
                        rows.append(parse_kv_line(line))
        except Exception:
            return rows
    return rows

def ensure_totals(src):
    base = {"CRIT": 0, "WARN": 0, "UNKNOWN": 0, "SKIP": 0, "OK": 0}
    if isinstance(src, dict):
        for k in base:
            try:
                base[k] = int(src.get(k, 0))
            except Exception:
                base[k] = 0
    return base

def status_rank(st):
    return {"OK": 0, "WARN": 1, "CRIT": 2, "UNKNOWN": 3, "SKIP": 3}.get(st, 3)

status = read_json(status_path)
trend = read_json(trend_path)
runtimes = read_json(runtimes_path)

if status_rc != 0:
    print("ERROR: metrics requires a successful status --json snapshot", file=sys.stderr)
    raise SystemExit(2)
if not isinstance(status, dict) or "last_status" not in status or "totals" not in status:
    print("ERROR: metrics requires valid JSON from status --json", file=sys.stderr)
    raise SystemExit(2)

summary_file = ""
if isinstance(status, dict):
    summary_file = status.get("summary_file") or ""

rows = read_summary_rows(summary_file)

severity_totals = ensure_totals(status.get("totals") if isinstance(status, dict) else {})
if not rows and not any(severity_totals.values()):
    severity_totals = {"CRIT": 0, "WARN": 0, "UNKNOWN": 0, "SKIP": 0, "OK": 0}
elif rows and not any(severity_totals.values()):
    for r in rows:
        st = (r.get("status") or "UNKNOWN").upper()
        if st not in severity_totals:
            st = "UNKNOWN"
        severity_totals[st] += 1

host_status = {}
for r in rows:
    host = r.get("host") or ""
    if not host:
        continue
    st = (r.get("status") or "UNKNOWN").upper()
    if st not in severity_totals:
        st = "UNKNOWN"
    prev = host_status.get(host)
    if prev is None or status_rank(st) >= status_rank(prev):
        host_status[host] = st

host_counts = {"CRIT": 0, "WARN": 0, "UNKNOWN": 0, "SKIP": 0, "OK": 0}
for st in host_status.values():
    host_counts[st] = host_counts.get(st, 0) + 1

monitor_durations_ms = {}
if isinstance(runtimes, dict):
    for row in runtimes.get("rows", []) or []:
        if not isinstance(row, dict):
            continue
        mon = row.get("monitor")
        ms = row.get("ms")
        if mon is None or ms is None:
            continue
        try:
            ms_val = int(ms)
        except Exception:
            continue
        prev = monitor_durations_ms.get(mon)
        if prev is None or ms_val > prev:
            monitor_durations_ms[mon] = ms_val

monitor_durations_seconds = {}
for mon, ms_val in monitor_durations_ms.items():
    try:
        monitor_durations_seconds[mon] = round(float(ms_val) / 1000.0, 3)
    except Exception:
        continue

top_n = 5
try:
    top_n = int(os.environ.get("LM_METRICS_TOP_SLOW", "5") or 5)
except Exception:
    top_n = 5
top_n = max(1, min(20, top_n))

slow_monitors_top = []
for mon, ms_val in sorted(monitor_durations_ms.items(), key=lambda kv: (-kv[1], kv[0]))[:top_n]:
    secs = monitor_durations_seconds.get(mon)
    row = {"monitor": mon, "ms": ms_val}
    if secs is not None:
        row["seconds"] = secs
    slow_monitors_top.append(row)

out = {
    "schema_version": 1,
    "run_id": (status.get("run_id") if isinstance(status, dict) else "") or (status.get("last_status", {}) if isinstance(status, dict) else {}).get("run_id", ""),
    "metrics_json_contract_version": 1,
    "status": status,
    "trend": trend,
    "runtimes": runtimes,
    "severity_totals": severity_totals,
    "host_counts": host_counts,
    "monitor_durations_ms": monitor_durations_ms,
    "monitor_durations_seconds": monitor_durations_seconds,
    "slow_monitors_top": slow_monitors_top,
}

if redact_json or redact_json_strict:
    out = redact_json_obj(out)
print(json.dumps(out, indent=2, sort_keys=True))
PY

    rm -f "$tmp_status" "$tmp_trend" "$tmp_runtimes" 2>/dev/null || true
}

linux_maint_cmd_summary() {
    SUMMARY_COLOR=1
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --no-color) SUMMARY_COLOR=0; shift 1;;
        -h|--help)
          echo "Usage: linux-maint summary [--no-color]"
          exit 0;;
        *) echo "Unknown summary flag: $1" >&2; exit 2;;
      esac
    done
    [[ -n "${NO_COLOR:-}" || -n "${LM_NO_COLOR:-}" ]] && SUMMARY_COLOR=0
    color_enabled || SUMMARY_COLOR=0

    tmp_status="$(mktemp -p "$TMPDIR" linux_maint_summary_status.XXXXXX.json)"
    status_rc=0
    "$0" status --json --problems 0 >"$tmp_status" 2>/dev/null || status_rc=$?

    LM_COLOR="$SUMMARY_COLOR" SUMMARY_STATUS_RC="$status_rc" python3 - "$tmp_status" <<'PY'
import json, os, sys

path = sys.argv[1]
color = os.environ.get("LM_COLOR","1") == "1"
status_rc = int(os.environ.get("SUMMARY_STATUS_RC", "0"))

def c(s, code):
    if not color:
        return s
    return f"\033[{code}m{s}\033[0m"

def color_status(st, text=None):
    label = text if text is not None else st
    if st == "CRIT":
        return c(label,"1;31")
    if st == "WARN":
        return c(label,"1;33")
    if st == "OK":
        return c(label,"1;32")
    if st == "UNKNOWN":
        return c(label,"1;35")
    if st == "SKIP":
        return c(label,"1;36")
    return label

def final_label(cmd, result):
    mapping = {
        "OK": ("1;32", "ok"),
        "WARN": ("1;33", "warn"),
        "CRIT": ("1;31", "crit"),
        "UNKNOWN": ("1;33", "unknown"),
        "SKIP": ("1;36", "skip"),
    }
    code, word = mapping.get(result, ("1;33", str(result).lower()))
    return c(f"{cmd} {word}", code)

try:
    with open(path, "r", encoding="utf-8") as f:
        status = json.load(f)
except Exception:
    print("ERROR: summary requires valid JSON from status --json", file=sys.stderr)
    raise SystemExit(2)
if status_rc != 0:
    print("ERROR: summary requires a successful status --json snapshot", file=sys.stderr)
    raise SystemExit(2)
if not isinstance(status, dict) or "last_status" not in status or "totals" not in status:
    print("ERROR: summary requires status --json contract fields", file=sys.stderr)
    raise SystemExit(2)

last = status.get("last_status", {})
overall = last.get("overall", "UNKNOWN")
exit_code = last.get("exit_code", "3")
summary_file = status.get("summary_file","")
totals = status.get("totals", {})

ov = color_status(overall)

parts = [
    f"overall={ov}",
    f"exit_code={exit_code}",
]
for k in ["CRIT","WARN","UNKNOWN","SKIP","OK"]:
    v = totals.get(k,0)
    kv = f"{k}={v}"
    if v != 0:
        kv = color_status(k, kv)
    parts.append(kv)
if summary_file:
    parts.append(f"summary={summary_file}")

print(" ".join(parts))
if overall != "OK":
    print("")
    print("== Guidance ==")
    print("next_step: linux-maint status --verbose")
    print("next_step: linux-maint doctor")
print("")
print("== Summary ==")
print(f"overall={overall}")
print(f"exit_code={exit_code}")
print(f"result={overall}")
print(final_label("summary", overall))
PY
    rm -f "$tmp_status" 2>/dev/null || true
}

linux_maint_cmd_status() {
    ONLY=""
    TAIL_N=200
    VERBOSE=0
    QUIET=0
    PROB_N=20
    JSON=0
    LAST_N=0
    HOST_FILTER=""
    MONITOR_FILTER=""
    MATCH_MODE="contains"
    REASONS_N=0
    SINCE=""
    TABLE=0
    SUMMARY_ONLY=0
    SHOW_META=1
    EXPECTED_SKIPS=0
    GROUP_BY=""
    TOP_N=0
    PROM=0
    STRICT=0
    OUTPUT_PATH=""
    local inventory_cfg_dir inventory_meta_file inventory_servers_file inventory_hosts_dir inventory_json=""
    local inventory_result="" inventory_warning_count=0 inventory_hosts=0 inventory_metadata_hosts=0
    local inventory_missing_hosts=0 inventory_extra_hosts=0 inventory_invalid_rows=0 inventory_coverage_percent=0
    local inventory_roles="" inventory_envs="" inventory_tags="" inventory_meta_present=0 inventory_meta_readable=0
    local inventory_meta_path="" inventory_show=0
    local baseline_json="" baseline_result="" baseline_stale_days="${LM_BASELINE_STALE_DAYS:-30}"
    local baseline_show=0 baseline_stale_items=0 baseline_fresh_items=0 baseline_drift_items=0
    local baseline_missing_inputs=0 baseline_changed_hosts_total=0 baseline_attention_count=0
    local baseline_next_step_primary=""


    while [[ $# -gt 0 ]]; do
      case "$1" in
        --only) ONLY="$2"; shift 2;;
        --tail) TAIL_N="$2"; shift 2;;
        --verbose) VERBOSE=1; shift 1;;
        --quiet) QUIET=1; shift 1;;
        --json) JSON=1; shift 1;;
        --no-color) LM_COLOR=0; shift 1;;
        --table) TABLE=1; shift 1;;
        --summary) SUMMARY_ONLY=1; shift 1;;
        --expected-skips) EXPECTED_SKIPS=1; shift 1;;
        --compact) SHOW_META=0; shift 1;;
        --host) HOST_FILTER="$2"; shift 2;;
        --monitor) MONITOR_FILTER="$2"; shift 2;;
        --match-mode) MATCH_MODE="$2"; shift 2;;
        --problems) PROB_N="$2"; shift 2;;
        --reasons) REASONS_N="$2"; shift 2;;
        --group-by) GROUP_BY="$2"; shift 2;;
        --top) TOP_N="$2"; shift 2;;
        --prom) PROM=1; shift 1;;
        --output) OUTPUT_PATH="$2"; shift 2;;
        --since) SINCE="$2"; shift 2;;
        --last) LAST_N="$2"; shift 2;;
        --strict) STRICT=1; shift 1;;
        -h|--help)
          command_usage status
          exit 0;;
        *) echo "Unknown status flag: $1" >&2; exit 2;;
      esac
    done
    [[ -n "${NO_COLOR:-}" || -n "${LM_NO_COLOR:-}" ]] && LM_COLOR=0
    color_enabled || LM_COLOR=0

    if [[ "$JSON" -eq 1 && "$EXPECTED_SKIPS" -eq 1 ]]; then
      echo "ERROR: --expected-skips is not compatible with --json" >&2
      exit 2
    fi
    if [[ "$JSON" -eq 1 && "$PROM" -eq 1 ]]; then
      echo "ERROR: --prom is not compatible with --json" >&2
      exit 2
    fi

    if [[ -n "$OUTPUT_PATH" ]]; then
      if ! atomic_output_begin "$OUTPUT_PATH"; then
        echo "ERROR: unable to write output to $OUTPUT_PATH" >&2
        exit 2
      fi
      trap atomic_output_end EXIT
    fi

    status_file="$(linux_maint_reporting_status_file)"

    if [[ "$SUMMARY_ONLY" -eq 1 ]]; then
      "$0" summary --no-color
      [[ "$TABLE" -eq 1 ]] || exit 0
      echo ""
    fi

    if [[ "$EXPECTED_SKIPS" -eq 1 ]]; then
      cfg_dir="$(linux_maint_effective_cfg_dir)"
      expected_skips "$cfg_dir"
      echo ""
    fi

    if [[ "$PROM" -eq 1 ]]; then
      status_file="$(linux_maint_reporting_status_file)"
      summary_file="$(linux_maint_reporting_summary_latest)"

      python3 - "$status_file" "$summary_file" <<'PY'
import os, sys, re
from datetime import datetime, timezone

status_path, summary_path = sys.argv[1:3]

def read_kv(path):
    d={}
    if not path or not os.path.exists(path):
        return d
    try:
        with open(path,'r',encoding='utf-8',errors='ignore') as f:
            for line in f:
                line=line.strip()
                if not line or '=' not in line:
                    continue
                k,v=line.split('=',1)
                d[k]=v
    except Exception:
        return d
    return d

def get_kv(line, key):
    m=re.search(rf"\b{re.escape(key)}=([^ ]+)", line)
    return m.group(1) if m else None

status = read_kv(status_path)
overall = status.get("overall", "UNKNOWN")
exit_code_raw = status.get("exit_code", "")
timestamp_raw = status.get("timestamp", "")

def parse_exit_code(val):
    try:
        return int(val)
    except Exception:
        return -1

def parse_timestamp(ts):
    if not ts:
        return -1
    try:
        if ts.endswith("Z"):
            dt = datetime.strptime(ts, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
        else:
            dt = datetime.strptime(ts, "%Y-%m-%dT%H:%M:%S%z")
        return int(dt.timestamp())
    except Exception:
        return -1

exit_code = parse_exit_code(exit_code_raw)
run_epoch = parse_timestamp(timestamp_raw)

counts = {k:0 for k in ["OK","WARN","CRIT","UNKNOWN","SKIP"]}
if summary_path and os.path.exists(summary_path):
    try:
        with open(summary_path,'r',encoding='utf-8',errors='ignore') as f:
            for line in f:
                line=line.strip()
                if not line:
                    continue
                if not line.startswith("monitor="):
                    continue
                st = get_kv(line, "status") or "UNKNOWN"
                if st not in counts:
                    st = "UNKNOWN"
                counts[st] += 1
    except Exception:
        # Keep zero counts when summary is unreadable/missing permissions.
        pass

print("# HELP linux_maint_overall_status Overall status (labelled)")
print("# TYPE linux_maint_overall_status gauge")
for st in ["OK","WARN","CRIT","UNKNOWN","SKIP"]:
    val = 1 if st == overall else 0
    print(f"linux_maint_overall_status{{status=\"{st}\"}} {val}")
print("# HELP linux_maint_status_count Count of monitor results by status")
print("# TYPE linux_maint_status_count gauge")
for st in ["OK","WARN","CRIT","UNKNOWN","SKIP"]:
    print(f"linux_maint_status_count{{status=\"{st.lower()}\"}} {counts.get(st,0)}")
print("# HELP linux_maint_last_run_exit_code Exit code of last run (wrapper)")
print("# TYPE linux_maint_last_run_exit_code gauge")
print(f"linux_maint_last_run_exit_code {exit_code}")
print("# HELP linux_maint_last_run_timestamp Last run timestamp as epoch seconds (wrapper)")
print("# TYPE linux_maint_last_run_timestamp gauge")
print(f"linux_maint_last_run_timestamp {run_epoch}")
PY
      exit 0
    fi

    inventory_cfg_dir="$(linux_maint_effective_cfg_dir)"
    inventory_meta_file="${LM_INVENTORY_META:-$(linux_maint_effective_inventory_meta_file)}"
    inventory_servers_file="${LM_SERVERLIST:-$inventory_cfg_dir/servers.txt}"
    inventory_hosts_dir="${LM_HOSTS_DIR:-$inventory_cfg_dir/hosts.d}"
    inventory_json="$(linux_maint_inventory_snapshot_json "$inventory_cfg_dir" "$inventory_meta_file" "$inventory_servers_file" "$inventory_hosts_dir")"
    while IFS='=' read -r k v; do
      case "$k" in
        result) inventory_result="$v" ;;
        warning_count) inventory_warning_count="$v" ;;
        inventory_hosts) inventory_hosts="$v" ;;
        metadata_hosts) inventory_metadata_hosts="$v" ;;
        missing_metadata_hosts) inventory_missing_hosts="$v" ;;
        extra_metadata_hosts) inventory_extra_hosts="$v" ;;
        invalid_rows) inventory_invalid_rows="$v" ;;
        coverage_percent) inventory_coverage_percent="$v" ;;
        roles) inventory_roles="$v" ;;
        envs) inventory_envs="$v" ;;
        tags) inventory_tags="$v" ;;
        meta_present) inventory_meta_present="$v" ;;
        meta_readable) inventory_meta_readable="$v" ;;
        meta_file) inventory_meta_path="$v" ;;
        show) inventory_show="$v" ;;
      esac
    done < <(
      INVENTORY_JSON="$inventory_json" python3 - <<'PY'
import json
import os

try:
    payload = json.loads(os.environ.get("INVENTORY_JSON", "") or "{}")
except Exception:
    payload = {}
summary = payload.get("summary") or {}
coverage = payload.get("coverage") or {}
inventory_hosts = int(summary.get("inventory_hosts", 0) or 0)
meta_present = 1 if payload.get("meta_present") else 0
show = 1 if inventory_hosts > 0 or meta_present else 0
print(f"result={payload.get('result', 'WARN')}")
print(f"warning_count={len(payload.get('warnings') or [])}")
print(f"inventory_hosts={inventory_hosts}")
print(f"metadata_hosts={int(summary.get('metadata_hosts', 0) or 0)}")
print(f"missing_metadata_hosts={int(summary.get('missing_metadata_hosts', 0) or 0)}")
print(f"extra_metadata_hosts={int(summary.get('extra_metadata_hosts', 0) or 0)}")
print(f"invalid_rows={int(summary.get('invalid_rows', 0) or 0)}")
print(f"coverage_percent={int(summary.get('coverage_percent', 0) or 0)}")
print(f"roles={','.join(coverage.get('roles') or [])}")
print(f"envs={','.join(coverage.get('envs') or [])}")
print(f"tags={','.join((coverage.get('tags') or [])[:8])}")
print(f"meta_present={1 if payload.get('meta_present') else 0}")
print(f"meta_readable={1 if payload.get('meta_readable') else 0}")
print(f"meta_file={payload.get('meta_file', '')}")
print(f"show={show}")
PY
    )

    set +e
    baseline_json="$("$0" baseline status --json --stale-days "$baseline_stale_days" 2>/dev/null)"
    baseline_rc=$?
    set -e
    if [[ "$baseline_rc" -le 1 && -n "$baseline_json" ]]; then
      while IFS='=' read -r k v; do
        case "$k" in
          result) baseline_result="$v" ;;
          stale_days) baseline_stale_days="$v" ;;
          stale_items) baseline_stale_items="$v" ;;
          fresh_items) baseline_fresh_items="$v" ;;
          drift_items) baseline_drift_items="$v" ;;
          missing_inputs) baseline_missing_inputs="$v" ;;
          changed_hosts_total) baseline_changed_hosts_total="$v" ;;
          attention_count) baseline_attention_count="$v" ;;
          next_step_primary) baseline_next_step_primary="$v" ;;
          next_step_secondary) baseline_next_step_secondary="$v" ;;
          show) baseline_show="$v" ;;
        esac
      done < <(
        BASELINE_JSON_PAYLOAD="$baseline_json" python3 - <<'PY'
import json
import os

try:
    payload = json.loads(os.environ.get("BASELINE_JSON_PAYLOAD", "") or "{}")
except Exception:
    payload = {}
summary = payload.get("summary") or {}
items = payload.get("items") or []
next_steps = payload.get("next_steps") or []
show = 1 if any(int((row or {}).get("file_count", 0) or 0) > 0 for row in items) or int(summary.get("changed_hosts_total", 0) or 0) > 0 else 0
print(f"result={payload.get('result', 'WARN')}")
print(f"stale_days={int(payload.get('stale_days', 0) or 0)}")
print(f"stale_items={int(summary.get('stale_items', 0) or 0)}")
print(f"fresh_items={int(summary.get('fresh_items', 0) or 0)}")
print(f"drift_items={int(summary.get('drift_items', 0) or 0)}")
print(f"missing_inputs={int(summary.get('missing_inputs', 0) or 0)}")
print(f"changed_hosts_total={int(summary.get('changed_hosts_total', 0) or 0)}")
print(f"attention_count={len(payload.get('attention_items') or [])}")
print(f"next_step_primary={next_steps[0] if len(next_steps) > 0 else ''}")
print(f"show={show}")
PY
      )
    else
      baseline_json=""
    fi

    # Optional strict validation of summary lines (ensure monitor/host/status are valid).
    if [[ "$STRICT" -eq 1 ]]; then
      # Resolve summary file path the same way status does.
      if [[ "$MODE" == "repo" ]]; then
        summary_file="$REPO_SUMMARY_LATEST"
        log_dir="$(linux_maint_reporting_summary_dir)"
      else
        summary_file="$(linux_maint_reporting_summary_latest)"
        log_dir="$(linux_maint_reporting_summary_dir)"
      fi
      if [[ -n "$SINCE" ]]; then
        tmp_since="$(mktemp -p "$TMPDIR" linux_maint_status_since.XXXXXX.log)"
        _run_tmpfiles+=("$tmp_since")
        while IFS= read -r f; do
          [[ -f "$f" ]] || continue
          history_state_info="$(linux_maint_reporting_summary_history_file_state "$f")"
          history_state="${history_state_info%%:*}"
          history_detail="${history_state_info#*:}"
          if [[ "$history_state" != "ok" ]]; then
            echo "ERROR: strict status validation failed (bad history summary: $f [$history_state${history_detail:+:$history_detail}])" >&2
            exit 2
          fi
          cat "$f" >> "$tmp_since"
        done < <(python3 - "$log_dir" "$SINCE" <<'PY'
import os, re, sys, time
log_dir, since = sys.argv[1:3]
m = re.match(r'^(\d+)([smhd])$', since)
if not m:
    sys.exit(2)
num = int(m.group(1))
unit = m.group(2)
mult = {'s':1, 'm':60, 'h':3600, 'd':86400}[unit]
cutoff = time.time() - (num * mult)
pat = re.compile(r'^full_health_monitor_summary_(\d{4}-\d{2}-\d{2})_(\d{6})\.log$')
rows=[]
try:
    names=os.listdir(log_dir)
except FileNotFoundError:
    names=[]
for name in names:
    m2 = pat.match(name)
    if not m2:
        continue
    ts=f"{m2.group(1)} {m2.group(2)}"
    try:
        epoch=time.mktime(time.strptime(ts, "%Y-%m-%d %H%M%S"))
    except Exception:
        continue
    if epoch >= cutoff:
        rows.append((epoch, os.path.join(log_dir, name)))
rows.sort()
for _,p in rows:
    print(p)
PY
)
        summary_file="$tmp_since"
      fi
      if [[ ! -f "$summary_file" ]]; then
        echo "ERROR: strict status validation failed (missing summary file: $summary_file)" >&2
        exit 2
      fi
      if ! python3 - "$summary_file" <<'PY'
import sys
path = sys.argv[1]
allowed = {"OK","WARN","CRIT","UNKNOWN","SKIP"}
had = False
with open(path, "r", encoding="utf-8", errors="ignore") as f:
    for line in f:
        line = line.strip()
        if not line.startswith("monitor="):
            continue
        had = True
        has_monitor = has_host = has_status = False
        status = ""
        for tok in line.split():
            if "=" not in tok:
                print(f"bad token: {tok}", file=sys.stderr)
                sys.exit(2)
            key, val = tok.split("=", 1)
            if key == "monitor":
                has_monitor = True
            elif key == "host":
                has_host = True
            elif key == "status":
                has_status = True
                status = val
        if not (has_monitor and has_host and has_status):
            print(f"missing required fields: {line}", file=sys.stderr)
            sys.exit(2)
        if status not in allowed:
            print(f"invalid status: {status}", file=sys.stderr)
            sys.exit(2)
if not had:
    print("no monitor= lines found", file=sys.stderr)
    sys.exit(2)
PY
      then
        echo "ERROR: strict status validation failed" >&2
        exit 2
      fi
    fi

    case "$MATCH_MODE" in
      contains|exact|regex) ;;
      *)
        echo "ERROR: invalid --match-mode '$MATCH_MODE' (use contains|exact|regex)" >&2
        exit 2
        ;;
    esac
    case "$GROUP_BY" in
      ""|host|monitor|reason) ;;
      *)
        echo "ERROR: invalid --group-by '$GROUP_BY' (use host|monitor|reason)" >&2
        exit 2
        ;;
    esac
    if [[ ! "$TOP_N" =~ ^[0-9]+$ ]]; then
      echo "ERROR: --top must be a non-negative integer" >&2
      exit 2
    fi
    if (( TOP_N > 0 )) && [[ -z "$GROUP_BY" ]]; then
      echo "ERROR: --top requires --group-by" >&2
      exit 2
    fi

    # Validate/cap PROB_N (default 20, max 100)
    if [[ ! "$PROB_N" =~ ^[0-9]+$ ]]; then
      PROB_N=20

    elif (( PROB_N > 100 )); then
      PROB_N=100
    elif (( PROB_N < 0 )); then
      PROB_N=0
    fi

    # Validate/cap REASONS_N (default 0=disabled, max 20)
    if [[ ! "$REASONS_N" =~ ^[0-9]+$ ]]; then
      REASONS_N=0
    elif (( REASONS_N > 20 )); then
      REASONS_N=20
    elif (( REASONS_N < 0 )); then
      REASONS_N=0
    fi


    # Validate --since duration (optional): <int><s|m|h|d>
    if [[ -n "$SINCE" && ! "$SINCE" =~ ^[0-9]+[smhd]$ ]]; then
      echo "ERROR: invalid --since '$SINCE' (use like 30s, 15m, 2h, 1d)" >&2
      exit 2
    fi

    # History mode: show last N wrapper runs (best-effort)
    if [[ "${LAST_N:-0}" -gt 0 ]]; then
      local history_state_info history_state history_detail
      local -a history_candidates=()
      local -a history_warning_lines=()
      local shown=0
      log_dir="$(linux_maint_reporting_summary_dir)"
      mapfile -t history_candidates < <(find "$log_dir" -maxdepth 1 -type f -name 'full_health_monitor_summary_[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_[0-9][0-9][0-9][0-9][0-9][0-9].log' -printf '%T@ %p\n' 2>/dev/null | sort -nr | awk '{print $2}')
      echo "=== Last ${LAST_N} runs ==="
      color_total() {
        local kv="$1" key val
        key="${kv%%=*}"
        val="${kv#*=}"
        if [[ "$LM_COLOR" -ne 1 || -z "$val" || "$val" == "0" ]]; then
          printf '%s' "$kv"
          return
        fi
        case "$key" in
          CRIT) printf '%s' "${C_RED}${kv}${C_RESET}" ;;
          WARN) printf '%s' "${C_YELLOW}${kv}${C_RESET}" ;;
          UNKNOWN) printf '%s' "${C_YELLOW}${kv}${C_RESET}" ;;
          SKIP) printf '%s' "${C_CYAN}${kv}${C_RESET}" ;;
          OK) printf '%s' "${C_GREEN}${kv}${C_RESET}" ;;
          *) printf '%s' "$kv" ;;
        esac
      }
      for f in "${history_candidates[@]}"; do
        history_state_info="$(linux_maint_reporting_summary_history_file_state "$f")"
        history_state="${history_state_info%%:*}"
        history_detail="${history_state_info#*:}"
        if [[ "$history_state" != "ok" ]]; then
          if [[ "$history_state" == "malformed" ]]; then
            history_warning_lines+=("- skipped malformed history file: $f ($history_detail)")
          else
            history_warning_lines+=("- skipped ${history_state} history file: $f")
          fi
          continue
        fi
        ts="$(basename "$f" | sed -E "s/^full_health_monitor_summary_([0-9-]+)_(\\d+)[.]log$/\1T\2/")"
        totals="$(awk '/^monitor=/{for(i=1;i<=NF;i++) if($i ~ /^status=/){split($i,a,"="); s=a[2]; c[s]++}} END{printf("CRIT=%d WARN=%d UNKNOWN=%d SKIP=%d OK=%d",c["CRIT"]+0,c["WARN"]+0,c["UNKNOWN"]+0,c["SKIP"]+0,c["OK"]+0)}' "$f" 2>/dev/null)"
        if [[ "$LM_COLOR" -eq 1 ]]; then
          colored_totals=()
          for kv in $totals; do
            colored_totals+=("$(color_total "$kv")")
          done
          totals="${colored_totals[*]}"
        fi
        echo "$ts $totals file=$f"
        shown=$((shown + 1))
        if (( shown >= LAST_N )); then
          break
        fi
      done
      if (( shown == 0 )); then
        echo "No readable summary artifacts found in: $log_dir"
      fi
      if (( ${#history_warning_lines[@]} > 0 )); then
        echo ""
        echo "History warnings:"
        printf '%s\n' "${history_warning_lines[@]}"
      fi
      exit 0
    fi

    if [[ "$JSON" -eq 1 ]]; then
      # JSON mode: emit a single JSON object and exit.
      status_file="$(linux_maint_reporting_status_file)"
      summary_file="$(linux_maint_reporting_summary_latest)"
      log_dir="$(linux_maint_reporting_summary_dir)"
      history_warnings_json=""

      if [[ -n "$SINCE" ]]; then
        tmp_since="$(mktemp -p "$TMPDIR" linux_maint_status_since.XXXXXX.log)"
        _run_tmpfiles+=("$tmp_since")
        history_valid_files=0
        while IFS= read -r f; do
          [[ -f "$f" ]] || continue
          history_state_info="$(linux_maint_reporting_summary_history_file_state "$f")"
          history_state="${history_state_info%%:*}"
          history_detail="${history_state_info#*:}"
          if [[ "$history_state" == "ok" ]]; then
            cat "$f" >> "$tmp_since"
            history_valid_files=$((history_valid_files + 1))
          else
            if [[ -n "$history_warnings_json" ]]; then
              history_warnings_json+=$'\n'
            fi
            if [[ "$history_state" == "malformed" ]]; then
              history_warnings_json+="${history_state}:$f:$history_detail"
            else
              history_warnings_json+="${history_state}:$f"
            fi
          fi
        done < <(python3 - "$log_dir" "$SINCE" <<'PY'
import os, re, sys, time
log_dir, since = sys.argv[1:3]
m = re.match(r'^(\d+)([smhd])$', since)
if not m:
    sys.exit(2)
num = int(m.group(1))
unit = m.group(2)
mult = {'s':1, 'm':60, 'h':3600, 'd':86400}[unit]
cutoff = time.time() - (num * mult)
pat = re.compile(r'^full_health_monitor_summary_(\d{4}-\d{2}-\d{2})_(\d{6})\.log$')
rows=[]
try:
    names=os.listdir(log_dir)
except FileNotFoundError:
    names=[]
for name in names:
    m2 = pat.match(name)
    if not m2:
        continue
    ts=f"{m2.group(1)} {m2.group(2)}"
    try:
        epoch=time.mktime(time.strptime(ts, "%Y-%m-%d %H%M%S"))
    except Exception:
        continue
    if epoch >= cutoff:
        rows.append((epoch, os.path.join(log_dir, name)))
rows.sort()
for _,p in rows:
    print(p)
PY
)
        if (( history_valid_files > 0 )); then
          summary_file="$tmp_since"
        else
          summary_file=""
        fi
      fi

      STATUS_HISTORY_WARNINGS="$history_warnings_json" STATUS_INVENTORY_JSON="$inventory_json" STATUS_BASELINE_JSON="$baseline_json" python3 - "$MODE" "$status_file" "$summary_file" "$ONLY" "$PROB_N" "$HOST_FILTER" "$MONITOR_FILTER" "$MATCH_MODE" "$REASONS_N" <<'PY'
import json, os, re, sys

mode, status_path, summary_path, only, limit, host_filter, monitor_filter, match_mode, reasons_limit = sys.argv[1:10]
limit=int(limit)
reasons_limit=int(reasons_limit)
redact_json = os.environ.get("LM_REDACT_JSON","0") in ("1","true","TRUE","yes","YES")
redact_json_strict = os.environ.get("LM_REDACT_JSON_STRICT","0") in ("1","true","TRUE","yes","YES")
history_warnings_raw = os.environ.get("STATUS_HISTORY_WARNINGS", "")
inventory_raw = os.environ.get("STATUS_INVENTORY_JSON", "")
baseline_raw = os.environ.get("STATUS_BASELINE_JSON", "")

def read_kv(path):
    d={}
    if not path or not os.path.exists(path):
        return d
    try:
        with open(path,'r',encoding='utf-8',errors='ignore') as f:
            for line in f:
                line=line.strip()
                if not line or '=' not in line:
                    continue
                k,v=line.split('=',1)
                d[k]=v
    except Exception:
        return d
    return d

def get_kv(line, key):
    m=re.search(rf"\b{re.escape(key)}=([^ ]+)", line)
    return m.group(1) if m else None

def redact_line(s: str) -> str:
    pats = [
        (re.compile(r'(?i)\b([A-Za-z0-9_]*(password|passwd|token|api[_-]?key|secret|access[_-]?key|private[_-]?key|session([_-]?id)?|id[_-]?token|refresh[_-]?token|x[_-]?auth[_-]?token)[A-Za-z0-9_]*)=([^ \t]+)'), r'\1=REDACTED'),
        (re.compile(r'(?i)\b(Authorization:|X-Auth-Token:)\s+[^ \t]+'), r'\1 REDACTED'),
        (re.compile(r'(?i)\b(Bearer)\s+[A-Za-z0-9_.~+/-]+=*'), r'\1 REDACTED'),
        (re.compile(r'\b[0-9A-Za-z_-]{12,}\.[0-9A-Za-z_-]{12,}\.[0-9A-Za-z_-]{12,}\b'), 'REDACTED_JWT'),
        (re.compile(r'\bAKIA[0-9A-Z]{16}\b'), 'AKIA_REDACTED'),
        (re.compile(r'\bASIA[0-9A-Z]{16}\b'), 'ASIA_REDACTED'),
        (re.compile(r'\bgh[pousr]_[A-Za-z0-9]{20,}\b'), 'GH_REDACTED'),
        (re.compile(r'\bgithub_pat_[A-Za-z0-9_]{20,}\b'), 'GH_PAT_REDACTED'),
        (re.compile(r'\bxox[baprs]-[A-Za-z0-9-]{10,}\b'), 'SLACK_REDACTED'),
        (re.compile(r'\bAIza[0-9A-Za-z_-]{35}\b'), 'GCP_REDACTED'),
        (re.compile(r'\bya29\.[A-Za-z0-9_-]{10,}\b'), 'OAUTH_REDACTED'),
        (re.compile(r'-----BEGIN [A-Z ]*PRIVATE KEY-----'), '-----BEGIN PRIVATE KEY-----'),
        (re.compile(r'-----END [A-Z ]*PRIVATE KEY-----'), '-----END PRIVATE KEY-----'),
    ]
    out = s
    for pat, rep in pats:
        out = pat.sub(rep, out)
    return out

def redact_json_obj(obj):
    if isinstance(obj, dict):
        return {k: redact_json_obj(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [redact_json_obj(v) for v in obj]
    if isinstance(obj, str):
        if redact_json_strict:
            return "REDACTED"
        return redact_line(obj)
    return obj

def matched(value, flt):
    if not flt:
        return True
    if match_mode == 'contains':
        return flt in value
    if match_mode == 'exact':
        return value == flt
    try:
        return re.search(flt, value) is not None
    except re.error as e:
        print(f"ERROR: invalid regex for --match-mode regex: {e}", file=sys.stderr)
        sys.exit(2)

status=read_kv(status_path)
try:
    inventory = json.loads(inventory_raw) if inventory_raw else {}
except Exception:
    inventory = {}
if not isinstance(inventory, dict):
    inventory = {}
try:
    baseline = json.loads(baseline_raw) if baseline_raw else {}
except Exception:
    baseline = {}
if not isinstance(baseline, dict):
    baseline = {}
if baseline:
    baseline_items = baseline.get("items") or []
    baseline_summary = baseline.get("summary") or {}
    baseline_show = any(int((row or {}).get("file_count", 0) or 0) > 0 for row in baseline_items) or int(baseline_summary.get("changed_hosts_total", 0) or 0) > 0
    if not baseline_show:
        baseline = {}
run_id = ""
if isinstance(status, dict):
    run_id = status.get("run_id", "")
status_state = "missing"
status_errors = []
if status_path and os.path.exists(status_path):
    if os.access(status_path, os.R_OK):
        missing_keys = [k for k in ("overall", "exit_code", "timestamp", "run_id") if k not in status]
        if missing_keys:
            status_state = "malformed"
            status_errors = [f"missing:{k}" for k in missing_keys]
        else:
            status_state = "ok"
    else:
        status_state = "unreadable"
        status_errors = ["unreadable"]

counts={}
problems=[]
reason_counts={}
runtime_warnings=[]
if summary_path and os.path.exists(summary_path):
    try:
        with open(summary_path,'r',encoding='utf-8',errors='ignore') as f:
            for line in f:
                line=line.strip()
                if not line.startswith('monitor='):
                    continue
                st=get_kv(line,'status') or 'UNKNOWN'
                host=get_kv(line,'host') or ''
                monitor=get_kv(line,'monitor') or ''
                if only and st != only:
                    continue
                if not matched(host, host_filter):
                    continue
                if not matched(monitor, monitor_filter):
                    continue
                counts[st]=counts.get(st,0)+1
                if monitor == 'runtime_guard':
                    warn_entry={'status':st,'monitor':monitor,'host':host}
                    for key in ('reason','target_monitor','runtime_ms','threshold_ms'):
                        val=get_kv(line,key)
                        if val is not None:
                            warn_entry[key]=val
                    runtime_warnings.append(warn_entry)
                if st!='OK':
                    mon=monitor or 'unknown_monitor'
                    reason=get_kv(line,'reason')
                    entry={'status':st,'monitor':mon,'host':host}
                    if reason:
                        entry['reason']=reason
                        reason_counts[reason]=reason_counts.get(reason,0)+1
                    problems.append(entry)
    except Exception:
        pass

sev_order={'CRIT':0,'WARN':1,'UNKNOWN':2,'SKIP':3,'OK':4}
problems.sort(key=lambda e: sev_order.get(e.get('status','UNKNOWN'), 9))

out={
    'mode': mode,
    'schema_version': 1,
    'run_id': run_id,
    'status_json_contract_version': 1,
    'last_status_file': status_path if status_path and os.path.exists(status_path) else None,
    'last_status_state': status_state,
    'last_status_errors': status_errors,
    'last_status': status,
    'summary_file': summary_path if summary_path and os.path.exists(summary_path) else None,
    'totals': {k: counts.get(k,0) for k in ['CRIT','WARN','UNKNOWN','SKIP','OK']},
    'problems': problems[:limit],
    'runtime_warnings': runtime_warnings,
}
if inventory:
    out['inventory'] = {
        'meta_file': inventory.get('meta_file'),
        'meta_present': bool(inventory.get('meta_present')),
        'meta_readable': bool(inventory.get('meta_readable')),
        'result': inventory.get('result') or 'WARN',
        'summary': inventory.get('summary') or {},
        'coverage': inventory.get('coverage') or {},
        'warnings': inventory.get('warnings') or [],
    }
if baseline:
    out['baseline'] = baseline
if history_warnings_raw:
    warnings = []
    for raw in history_warnings_raw.splitlines():
        if not raw:
            continue
        parts = raw.split(":", 2)
        entry = {"state": parts[0], "file": parts[1] if len(parts) > 1 else ""}
        if len(parts) > 2:
            entry["detail"] = parts[2]
        warnings.append(entry)
    out['history_warnings'] = warnings
if reasons_limit > 0:
    rollup=sorted(reason_counts.items(), key=lambda kv: (-kv[1], kv[0]))
    out['reason_rollup']=[{'reason':r,'count':c} for r,c in rollup[:reasons_limit]]
if redact_json or redact_json_strict:
    out = redact_json_obj(out)
print(json.dumps(out, indent=2, sort_keys=True))
PY
      exit 0
    fi
    if [[ "$QUIET" -eq 0 && "$SHOW_META" -eq 1 ]]; then

      # Banner: overall health (best-effort)
      status_state_info="$(linux_maint_reporting_status_file_state "$status_file")"
      status_state="${status_state_info%%:*}"
      if [[ -f "$status_file" && "$status_state" == "ok" ]]; then
        overall_val="$(awk -F= '$1=="overall"{print $2}' "$status_file" 2>/dev/null || true)"
        exit_val="$(awk -F= '$1=="exit_code"{print $2}' "$status_file" 2>/dev/null || true)"
        banner="health=${overall_val:-UNKNOWN} exit_code=${exit_val:-3}"
        case "$overall_val" in
          CRIT) banner="${C_RED}${banner}${C_RESET}" ;;
          WARN) banner="${C_YELLOW}${banner}${C_RESET}" ;;
          OK)   banner="${C_GREEN}${banner}${C_RESET}" ;;
        esac
        if color_enabled; then
          echo "=== ${C_CYAN}linux-maint status${C_RESET} === $banner"
        else
          echo "=== linux-maint status === $banner"
        fi
      else
        section "linux-maint status"
      fi

    if [[ "$MODE" == "repo" ]]; then
      section "Mode"
      echo "repo"
      echo "repo_root: ${C_BOLD}${REPO_ROOT}${C_RESET}"
      echo "linux_maint_lib: ${C_BOLD}${LINUX_MAINT_LIB:-}${C_RESET}"
      echo "logs: ${C_BOLD}${REPO_LOG_DIR}${C_RESET}"
      echo ""; section "Last run status"
      status_state_info="$(linux_maint_reporting_status_file_state "$REPO_STATUS_FILE")"
      status_state="${status_state_info%%:*}"
      status_missing="${status_state_info#*:}"
      if [[ -f "$REPO_STATUS_FILE" && -r "$REPO_STATUS_FILE" ]]; then
        cat "$REPO_STATUS_FILE"
        if [[ "$status_state" == "malformed" ]]; then
          echo "Malformed status file: $REPO_STATUS_FILE (missing: ${status_missing//,/ , })"
        fi
      elif [[ -f "$REPO_STATUS_FILE" ]]; then
        echo "Unreadable status file: $REPO_STATUS_FILE"
      else
        echo "No status file: $REPO_STATUS_FILE"
      fi
    else
      section "Mode"
      echo "${C_BOLD}installed${C_RESET}"
      echo "prefix: ${C_BOLD}${PREFIX}${C_RESET}"
      echo ""; section "Installed paths"
      echo "wrapper: ${C_BOLD}$SBIN/run_full_health_monitor.sh${C_RESET}"
      echo "libexec: ${C_BOLD}$LIBEXEC${C_RESET}"
      echo "build_info: ${C_BOLD}$SHARE/BUILD_INFO${C_RESET}"
      [[ -f "$SHARE/BUILD_INFO" ]] && { echo ""; cat "$SHARE/BUILD_INFO"; }
      echo ""; section "Last run status"
      status_file="$(linux_maint_reporting_status_file)"
      status_state_info="$(linux_maint_reporting_status_file_state "$status_file")"
      status_state="${status_state_info%%:*}"
      status_missing="${status_state_info#*:}"
      if [[ -f "$status_file" && -r "$status_file" ]]; then
        cat "$status_file"
        if [[ "$status_state" == "malformed" ]]; then
          echo "Malformed status file: $status_file (missing: ${status_missing//,/ , })"
        fi
      elif [[ -f "$status_file" ]]; then
        echo "Unreadable status file: $status_file"
      else
        echo "No status file: $status_file"
      fi
    fi

    if [[ "$inventory_show" -eq 1 ]]; then
      echo ""; section "Inventory metadata"
      echo "result=${inventory_result:-WARN}"
      echo "meta_file=${inventory_meta_path:-$inventory_meta_file}"
      echo "inventory_hosts=${inventory_hosts:-0} metadata_hosts=${inventory_metadata_hosts:-0} coverage=${inventory_coverage_percent:-0}%"
      echo "missing_metadata_hosts=${inventory_missing_hosts:-0} extra_metadata_hosts=${inventory_extra_hosts:-0} invalid_rows=${inventory_invalid_rows:-0}"
      [[ -n "${inventory_roles:-}" ]] && echo "available_roles=${inventory_roles}"
      [[ -n "${inventory_envs:-}" ]] && echo "available_envs=${inventory_envs}"
      [[ -n "${inventory_tags:-}" ]] && echo "available_tags=${inventory_tags}"
    fi

    if [[ "$baseline_show" -eq 1 ]]; then
      echo ""; section "Baseline lifecycle"
      echo "result=${baseline_result:-WARN}"
      echo "stale_days=${baseline_stale_days:-30}"
      echo "stale_items=${baseline_stale_items:-0} fresh_items=${baseline_fresh_items:-0} drift_items=${baseline_drift_items:-0} missing_inputs=${baseline_missing_inputs:-0} changed_hosts_total=${baseline_changed_hosts_total:-0}"
      echo "attention_items=${baseline_attention_count:-0}"
      [[ -n "$baseline_next_step_primary" ]] && echo "next_step_hint=${baseline_next_step_primary}"
    fi

    fi

    # Default: compact summary (hide OK). Use --verbose to show full tail of summary file.
    VERBOSE=${VERBOSE:-0}

    if [[ "$QUIET" -eq 0 ]]; then
      echo ""; section "Summary (compact)"
      tip_line "Use --verbose to show raw monitor lines"
    fi
    summary_file=""
    if [[ "$MODE" == "repo" ]]; then
      summary_file="$REPO_SUMMARY_LATEST"
      log_dir="$(linux_maint_reporting_summary_dir)"
    else
      summary_file="$(linux_maint_reporting_summary_latest)"
      log_dir="$(linux_maint_reporting_summary_dir)"
    fi

    if [[ "$QUIET" -eq 0 && "$SUMMARY_ONLY" -eq 0 && "$EXPECTED_SKIPS" -eq 0 && "$SHOW_META" -eq 1 ]]; then
      cfg_dir="$(linux_maint_effective_cfg_dir)"
      if banner="$(expected_skips_text "$cfg_dir")"; then
        echo "$banner"
        echo ""
      fi
    fi

    if [[ -n "$SINCE" ]]; then
      tmp_since="$(mktemp -p "$TMPDIR" linux_maint_status_since.XXXXXX.log)"
      _run_tmpfiles+=("$tmp_since")
      history_valid_files=0
      history_warning_lines=()
      while IFS= read -r f; do
        [[ -f "$f" ]] || continue
        history_state_info="$(linux_maint_reporting_summary_history_file_state "$f")"
        history_state="${history_state_info%%:*}"
        history_detail="${history_state_info#*:}"
        if [[ "$history_state" == "ok" ]]; then
          cat "$f" >> "$tmp_since"
          history_valid_files=$((history_valid_files + 1))
        else
          if [[ "$history_state" == "malformed" ]]; then
            history_warning_lines+=("- skipped malformed history file: $f ($history_detail)")
          else
            history_warning_lines+=("- skipped ${history_state} history file: $f")
          fi
        fi
      done < <(python3 - "$log_dir" "$SINCE" <<'PY'
import os, re, sys, time
log_dir, since = sys.argv[1:3]
m = re.match(r'^(\d+)([smhd])$', since)
if not m:
    sys.exit(2)
num = int(m.group(1))
unit = m.group(2)
mult = {'s':1, 'm':60, 'h':3600, 'd':86400}[unit]
cutoff = time.time() - (num * mult)
pat = re.compile(r'^full_health_monitor_summary_(\d{4}-\d{2}-\d{2})_(\d{6})\.log$')
rows=[]
try:
    names=os.listdir(log_dir)
except FileNotFoundError:
    names=[]
for name in names:
    m2 = pat.match(name)
    if not m2:
        continue
    ts=f"{m2.group(1)} {m2.group(2)}"
    try:
        epoch=time.mktime(time.strptime(ts, "%Y-%m-%d %H%M%S"))
    except Exception:
        continue
    if epoch >= cutoff:
        rows.append((epoch, os.path.join(log_dir, name)))
rows.sort()
for _,p in rows:
    print(p)
PY
)
      if (( history_valid_files > 0 )); then
        summary_file="$tmp_since"
      else
        summary_file=""
      fi
    fi

    if [[ -f "$summary_file" && -r "$summary_file" ]]; then
      if [[ "$VERBOSE" -eq 1 ]]; then
        echo "(verbose; last $TAIL_N lines from: $summary_file)"
        if [[ -n "$ONLY" || -n "$HOST_FILTER" || -n "$MONITOR_FILTER" ]]; then
          python3 - "$summary_file" "$TAIL_N" "$ONLY" "$HOST_FILTER" "$MONITOR_FILTER" "$MATCH_MODE" <<'PY'
import re, sys

path, tail_n, only, host_filter, monitor_filter, match_mode = sys.argv[1:7]
tail_n=int(tail_n)

def get_kv(line, key):
    m=re.search(rf"\b{re.escape(key)}=([^ ]+)", line)
    return m.group(1) if m else None

def matched(value, flt):
    if not flt:
        return True
    if match_mode == 'contains':
        return flt in value
    if match_mode == 'exact':
        return value == flt
    try:
        return re.search(flt, value) is not None
    except re.error as e:
        print(f"ERROR: invalid regex for --match-mode regex: {e}", file=sys.stderr)
        sys.exit(2)

matched=[]
with open(path, 'r', encoding='utf-8', errors='ignore') as f:
    for line in f:
        line=line.strip()
        if not line.startswith('monitor='):
            continue
        st=get_kv(line,'status') or 'UNKNOWN'
        host=get_kv(line,'host') or ''
        monitor=get_kv(line,'monitor') or ''
        if only and st != only:
            continue
        if not matched(host, host_filter):
            continue
        if not matched(monitor, monitor_filter):
            continue
        matched.append(line)

for line in matched[-tail_n:]:
    print(line)
PY
        else
          tail -n "$TAIL_N" "$summary_file" || true
        fi
      else
        [[ "$QUIET" -eq 0 ]] && echo "(from: $summary_file)"
      STATUS_QUIET="$QUIET" LM_COLOR="$LM_COLOR" python3 - "$summary_file" "$ONLY" "$PROB_N" "$HOST_FILTER" "$MONITOR_FILTER" "$MATCH_MODE" "$REASONS_N" "$TABLE" "$GROUP_BY" "$TOP_N" <<'PY'
import re, sys, os
path, only, limit, host_filter, monitor_filter, match_mode, reasons_limit, table, group_by, top_n = sys.argv[1:11]
limit=int(limit)
reasons_limit=int(reasons_limit)
top_n=int(top_n)
color = os.environ.get("LM_COLOR","1") == "1"
table = table == "1"
group_by = group_by.strip()
quiet = os.environ.get("STATUS_QUIET","0") == "1"

def c(s, code):
    if not color:
        return s
    return f"\033[{code}m{s}\033[0m"

def section(title):
    if quiet:
        return
    print(c(title, "1;36"))

# Example line:
# monitor=config_validate host=localhost status=WARN node=localhost warn=1 crit=0 reason=...

def get_kv(line, key):
    m=re.search(rf"\b{re.escape(key)}=([^ ]+)", line)
    return m.group(1) if m else None

def matched(value, flt):
    if not flt:
        return True
    if match_mode == 'contains':
        return flt in value
    if match_mode == 'exact':
        return value == flt
    try:
        return re.search(flt, value) is not None
    except re.error as e:
        print(f"ERROR: invalid regex for --match-mode regex: {e}", file=sys.stderr)
        sys.exit(2)

counts={}
problems=[]
reason_counts={}
groups={}
with open(path, 'r', encoding='utf-8', errors='ignore') as f:
    for line in f:
        line=line.strip()
        if not line:
            continue
        st=get_kv(line,'status') or 'UNKNOWN'
        host=get_kv(line,'host') or ''
        monitor=get_kv(line,'monitor') or ''
        reason=get_kv(line,'reason') or ''
        if only and st != only:
            continue
        if not matched(host, host_filter):
            continue
        if not matched(monitor, monitor_filter):
            continue
        counts[st]=counts.get(st,0)+1
        if group_by:
            if group_by == 'host':
                key = host or 'unknown_host'
            elif group_by == 'monitor':
                key = monitor or 'unknown_monitor'
            else:
                key = reason
                if not key:
                    key = ""
            if group_by != 'reason' or key:
                g = groups.setdefault(key, {})
                g[st]=g.get(st,0)+1
        if st == 'OK':
            continue
        mon=monitor or 'unknown_monitor'
        problems.append({
            "status": st,
            "monitor": mon,
            "host": host,
            "reason": reason or "",
        })
        if reason:
            reason_counts[reason]=reason_counts.get(reason,0)+1

def color_status(st, text=None):
    label = text if text is not None else st
    if st=="CRIT":
        return c(label,'1;31')
    if st=="WARN":
        return c(label,'1;33')
    if st=="OK":
        return c(label,'1;32')
    if st=="UNKNOWN":
        return c(label,'1;35')
    if st=="SKIP":
        return c(label,'1;36')
    return label

order=['CRIT','WARN','UNKNOWN','SKIP','OK']
if not quiet:
    filters=[]
    if only:
        filters.append(f"only={only}")
    if host_filter:
        filters.append(f"host={host_filter}")
    if monitor_filter:
        filters.append(f"monitor={monitor_filter}")
    if (host_filter or monitor_filter) and match_mode:
        filters.append(f"match_mode={match_mode}")
    if group_by:
        filters.append(f"group_by={group_by}")
    if group_by and top_n > 0:
        filters.append(f"top={top_n}")
    if filters:
        print(c("filters: " + " ".join(filters), "1;36"))
if table:
    section("totals")
    print(c("totals:", "1;36"))
    maxk=max(len(k) for k in order)
    maxv=max(len(str(counts.get(k,0))) for k in order)
    print(f"  {'STATUS':<{maxk}} {'COUNT':<{maxv}}")
    for k in order:
        v=str(counts.get(k,0))
        label = color_status(k, f"{k:<{maxk}}")
        count = f"{v:<{maxv}}"
        if v != "0":
            count = color_status(k, count)
        print(f"  {label} {count}")
else:
    section("totals")
    parts=[]
    for k in order:
        v=str(counts.get(k,0))
        kv=f"{k}={v}"
        if v != "0":
            kv=color_status(k, kv)
        parts.append(kv)
    print('totals: ' + ' '.join(parts))

if group_by:
    if not quiet:
        print("")
    print(c(f"group_by={group_by}", "1;36"))
    print(c("groups:", "1;36"))
    def group_key(item):
        name, data = item
        worst = len(order)
        for i, st in enumerate(order):
            if data.get(st, 0) > 0:
                worst = i
                break
        return (worst, name)
    rows = sorted(groups.items(), key=group_key)
    if top_n > 0:
        rows = rows[:top_n]
    if table:
        maxg = max([len("GROUP")] + [len(n) for n,_ in rows]) if rows else len("GROUP")
        headers = ["CRIT","WARN","UNKNOWN","SKIP","OK","TOTAL"]
        maxv = {}
        for h in headers:
            maxv[h]=len(h)
        for _, data in rows:
            total = sum(data.get(st,0) for st in order)
            for h in headers:
                val = total if h == "TOTAL" else data.get(h,0)
                maxv[h]=max(maxv[h], len(str(val)))
        header_line = f"{'GROUP':<{maxg}} " + " ".join(f"{h:<{maxv[h]}}" for h in headers)
        print(header_line)
        for name, data in rows:
            total = sum(data.get(st,0) for st in order)
            parts = []
            for h in headers:
                val = total if h == "TOTAL" else data.get(h,0)
                cell = f"{val:<{maxv[h]}}"
                if h != "TOTAL" and str(val) != "0":
                    cell = color_status(h, cell)
                parts.append(cell)
            print(f"{name:<{maxg}} " + " ".join(parts))
    else:
        for name, data in rows:
            total = sum(data.get(st,0) for st in order)
            parts = []
            for st in order:
                val = data.get(st,0)
                kv = f"{st}={val}"
                if val != 0:
                    kv = color_status(st, kv)
                parts.append(kv)
            parts.append(f"TOTAL={total}")
            print(f"{name} " + " ".join(parts))

if problems:
    sev_order={'CRIT':0,'WARN':1,'UNKNOWN':2,'SKIP':3}
    problems.sort(key=lambda r: sev_order.get(r["status"], 9))
    show_n=min(limit, len(problems))
    if not quiet:
        print("")
    print(c(f"problems (top {show_n}):", "1;36"))
    if table:
        rows=[(p["status"], p["monitor"], p["host"], p["reason"]) for p in problems[:limit]]
        headers=("STATUS","MONITOR","HOST","REASON")
        w=[len(h) for h in headers]
        for r in rows:
            for i,v in enumerate(r):
                w[i]=max(w[i], len(str(v)))
        print(f"{headers[0]:<{w[0]}} {headers[1]:<{w[1]}} {headers[2]:<{w[2]}} {headers[3]}")
        for st,mon,host,reason in rows:
            s_pad=color_status(st, f"{st:<{w[0]}}")
            print(f"{s_pad} {mon:<{w[1]}} {host:<{w[2]}} {reason}")
    else:
        for p in problems[:limit]:
            st=color_status(p["status"])
            line=f"{st} {p['monitor']} host={p['host']}"
            if p["reason"]:
                line += f" reason={p['reason']}"
            print(line)
    if not quiet:
        print(c("\ntip: run 'linux-maint doctor' for fix suggestions", "1;33"))
else:
    if not quiet:
        print("")
    print(c('problems: none (all OK)', "1;32"))

if reasons_limit > 0:
    if not quiet:
        print("")
    print(c(f"reasons (top {reasons_limit}):", "1;36"))
    if reason_counts:
        rollup=sorted(reason_counts.items(), key=lambda kv: (-kv[1], kv[0]))
        for reason, count in rollup[:reasons_limit]:
            print(f"{reason}={count}")
        hints_map = {
            "permission_denied": "Run with sudo or fix permissions for logs/state/config.",
            "missing_optional_cmd": "Install the optional dependency listed in the monitor output.",
            "missing_dependency": "Install the required dependency on the runner/host.",
            "kernel_log_unreadable": "Check journal/dmesg permissions and ensure kernel logs are readable.",
            "collect_failed": "Inventory export failed; verify /var/log/inventory and required tools (ip, lsblk, lscpu).",
            "ports_baseline_changed": "Review listening port changes and update the baseline if expected.",
            "config_drift_changed": "Review config changes and update the baseline if intended.",
            "user_anomalies": "Review new/removed users and sudoers changes.",
            "ntp_drift_high": "Check NTP/chrony sync and clock drift.",
            "ntp_not_synced": "Check NTP/chrony sync.",
            "missing_log_source": "Ensure journald/syslog is available and readable.",
            "security_updates_pending": "Apply security updates via your package manager.",
            "updates_pending": "Apply pending package updates.",
            "baseline_missing": "Create a baseline via linux-maint baseline.",
            "baseline_created": "Baseline created; rerun to compare changes.",
            "baseline_updated": "Baseline updated; rerun to check for drift.",
            "baseline_exists": "Baseline already exists; use --update if you want to overwrite it.",
            "baseline_collect_failed": "Baseline collection failed; check permissions/SSH and retry.",
            "timer_missing": "Install/enable linux-maint.timer if you want scheduled runs.",
            "timer_disabled": "Enable linux-maint.timer (systemctl enable --now linux-maint.timer).",
            "timer_inactive": "Start linux-maint.timer (systemctl start linux-maint.timer).",
            "ssh_unreachable": "Verify SSH connectivity and credentials for the target host.",
            "stale_run": "Check timers/cron; last run appears too old.",
        }
        hints=[]
        for reason, _count in rollup[:reasons_limit]:
            if reason in hints_map and reason not in hints:
                hints.append(reason)
        if hints:
            print("\nhints:")
            for reason in hints[:5]:
                print(f"- {reason}: {hints_map[reason]}")
    else:
        print('none')
PY
      fi
    else
      if [[ "$MODE" == "repo" ]]; then
        missing_summary_log_dir="$(linux_maint_reporting_summary_dir)"
        missing_summary_run_cmd="linux-maint run"
        missing_summary_logs_cmd="linux-maint logs 200"
        missing_summary_doctor_cmd="linux-maint doctor"
      else
        missing_summary_log_dir="$(linux_maint_reporting_summary_dir)"
        missing_summary_run_cmd="sudo linux-maint run"
        missing_summary_logs_cmd="sudo linux-maint logs 200"
        missing_summary_doctor_cmd="linux-maint doctor"
      fi
      if [[ -f "$summary_file" ]]; then
        echo "Unreadable summary file: $summary_file"
      else
        echo "No summary file: $summary_file"
      fi
      if [[ "$TABLE" -eq 1 ]]; then
        echo "STATUS MONITOR HOST REASON"
      fi
      if color_enabled; then
        echo "${C_CYAN}Likely causes:${C_RESET}"
      else
        echo "Likely causes:"
      fi
      echo "- The wrapper has not been run yet"
      echo "- LOG_DIR/SUMMARY_DIR points elsewhere"
      echo "- Permission issue writing to $missing_summary_log_dir"
      if color_enabled; then
        echo "${C_CYAN}Next steps:${C_RESET}"
      else
        echo "Next steps:"
      fi
      echo "- Run: $missing_summary_run_cmd"
      echo "- Check logs: $missing_summary_logs_cmd"
      echo "- Diagnose: $missing_summary_doctor_cmd"
      echo "Falling back to grepping latest wrapper log"
      log="$(linux_maint_reporting_latest_log)"
      [[ "$MODE" == "repo" ]] && log="$REPO_LATEST_LOG"
      if [[ -f "$log" ]]; then
        grep -E " status=(WARN|CRIT|UNKNOWN)|SKIP:|SUMMARY_RESULT|FINAL_STATUS_SUMMARY|^\\[.*\\] monitor=" "$log" | tail -n 120 || true
      else
        echo "No log found at: $log"
        hint_line "run linux-maint run to generate logs"
      fi
      if [[ -n "${history_warning_lines+x}" && ${#history_warning_lines[@]} -gt 0 ]]; then
        echo ""
        echo "History warnings:"
        printf '%s\n' "${history_warning_lines[@]}"
      fi
    fi
    if [[ -n "${history_warning_lines+x}" && ${#history_warning_lines[@]} -gt 0 ]] && [[ -f "$summary_file" && -r "$summary_file" ]]; then
      echo ""
      echo "History warnings:"
      printf '%s\n' "${history_warning_lines[@]}"
    fi
    if [[ "$QUIET" -eq 0 ]]; then
      status_state_info="$(linux_maint_reporting_status_file_state "$status_file")"
      status_state="${status_state_info%%:*}"
      status_overall="UNKNOWN"
      status_exit="3"
      history_warning_count=0
      if [[ -n "${history_warning_lines+x}" ]]; then
        history_warning_count="${#history_warning_lines[@]}"
      fi
      if [[ -f "$status_file" && -r "$status_file" && "$status_state" == "ok" ]]; then
        status_overall="$(awk -F= '$1=="overall"{print $2}' "$status_file" 2>/dev/null || printf 'UNKNOWN\n')"
        status_exit="$(awk -F= '$1=="exit_code"{print $2}' "$status_file" 2>/dev/null || printf '3\n')"
      fi
      echo ""
      echo "== Guidance =="
      if [[ "$status_overall" == "OK" ]]; then
        echo "next_step: linux-maint run"
      else
        echo "next_step: linux-maint doctor"
        echo "next_step: linux-maint status --verbose"
      fi
      if [[ "${inventory_show:-0}" -eq 1 && "${inventory_result:-OK}" != "OK" ]]; then
        echo "next_step: linux-maint inventory lint"
      fi
      if [[ "${baseline_show:-0}" -eq 1 && "${baseline_result:-OK}" != "OK" ]]; then
        echo "next_step: linux-maint baseline refresh --plan"
      fi
      if [[ "$history_warning_count" -gt 0 ]]; then
        echo "next_step: linux-maint status --since 1d"
      fi
      echo ""
      echo "== Summary =="
      echo "overall=$status_overall"
      echo "exit_code=$status_exit"
      echo "history_warnings=$history_warning_count"
      if [[ "${inventory_show:-0}" -eq 1 ]]; then
        echo "inventory_result=${inventory_result:-WARN}"
        echo "inventory_warnings=${inventory_warning_count:-0}"
        echo "inventory_coverage=${inventory_metadata_hosts:-0}/${inventory_hosts:-0}"
      fi
      if [[ "${baseline_show:-0}" -eq 1 ]]; then
        echo "baseline_result=${baseline_result:-WARN}"
        echo "baseline_attention=${baseline_attention_count:-0}"
      fi
      echo "result=$status_overall"
      case "$status_overall" in
        OK) echo "${C_GREEN}status ok${C_RESET}" ;;
        WARN) echo "${C_YELLOW}status warn${C_RESET}" ;;
        CRIT) echo "${C_RED}status crit${C_RESET}" ;;
        SKIP) echo "${C_CYAN}status skip${C_RESET}" ;;
        *) echo "${C_YELLOW}status unknown${C_RESET}" ;;
      esac
    fi
}

linux_maint_cmd_trend() {
    LAST_N=10
    JSON=0
    CSV=0
    REDACT=0
    SINCE=""
    UNTIL=""
    ANOMALY=0
    ANOMALY_Z="2.0"
    ANOMALY_WINDOW=5
    OUTPUT_PATH=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --last) LAST_N="$2"; shift 2 ;;
        --since|--from) SINCE="$2"; shift 2 ;;
        --until|--to) UNTIL="$2"; shift 2 ;;
        --anomaly) ANOMALY=1; shift 1 ;;
        --anomaly-z) ANOMALY_Z="$2"; shift 2 ;;
        --anomaly-window) ANOMALY_WINDOW="$2"; shift 2 ;;
        --json) JSON=1; shift 1 ;;
        --csv) CSV=1; shift 1 ;;
        --output) OUTPUT_PATH="$2"; shift 2 ;;
        --export)
          case "${2:-}" in
            csv) CSV=1; shift 2 ;;
            json) JSON=1; shift 2 ;;
            *) echo "ERROR: --export expects csv|json" >&2; exit 2 ;;
          esac
          ;;
        --redact) REDACT=1; shift 1 ;;
        -h|--help)
          command_usage trend
          exit 0 ;;
        *) echo "Unknown trend flag: $1" >&2; exit 2 ;;
      esac
    done

    if [[ ! "$LAST_N" =~ ^[0-9]+$ ]] || (( LAST_N <= 0 )); then
      echo "ERROR: --last must be a positive integer" >&2
      exit 2
    fi
    if [[ ! "$ANOMALY_WINDOW" =~ ^[0-9]+$ ]] || (( ANOMALY_WINDOW < 2 )); then
      echo "ERROR: --anomaly-window must be an integer >= 2" >&2
      exit 2
    fi
    if ! [[ "$ANOMALY_Z" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
      echo "ERROR: --anomaly-z must be a positive number" >&2
      exit 2
    fi
    if [[ "$JSON" -eq 1 && "$CSV" -eq 1 ]]; then
      echo "ERROR: choose only one output format (--json or --csv)" >&2
      exit 2
    fi
    if [[ "$REDACT" -eq 1 && ( "$JSON" -eq 1 || "$CSV" -eq 1 ) ]]; then
      echo "ERROR: --redact is only for human output" >&2
      exit 2
    fi

    if [[ -n "$OUTPUT_PATH" ]]; then
      if ! atomic_output_begin "$OUTPUT_PATH"; then
        echo "ERROR: unable to write output to $OUTPUT_PATH" >&2
        exit 2
      fi
      trap atomic_output_end EXIT
    fi

    log_dir="$(linux_maint_reporting_summary_dir)"
    if [[ "$MODE" == "repo" ]]; then
      cache_dir="${LM_STATE_DIR:-$REPO_LOG_DIR}"
    else
      cache_dir="${LM_STATE_DIR:-/var/lib/linux_maint}"
    fi

    TREND_COLOR=0
    color_enabled && TREND_COLOR=1
    LM_COLOR="$TREND_COLOR" TREND_REDACT="$REDACT" TREND_CACHE="${LM_TREND_CACHE:-0}" TREND_CACHE_TTL="${LM_TREND_CACHE_TTL:-60}" TREND_CACHE_FILE="${LM_TREND_CACHE_FILE:-$cache_dir/trend_cache.json}" python3 - "$log_dir" "$LAST_N" "$JSON" "$CSV" "$SINCE" "$UNTIL" "$ANOMALY" "$ANOMALY_Z" "$ANOMALY_WINDOW" <<'PY'
import glob, json, os, re, sys, time
import builtins

log_dir, last_n, json_mode, csv_mode, since_arg, until_arg, anomaly_enabled, anomaly_z, anomaly_window = sys.argv[1:10]
last_n=int(last_n)
json_mode = json_mode == '1'
csv_mode = csv_mode == '1'
anomaly_enabled = anomaly_enabled == '1'
anomaly_z = float(anomaly_z)
anomaly_window = int(anomaly_window)
color = os.environ.get("LM_COLOR","1") == "1"
redact = os.environ.get("TREND_REDACT","0") == "1"
redact_json = os.environ.get("LM_REDACT_JSON","0") in ("1","true","TRUE","yes","YES")
redact_json_strict = os.environ.get("LM_REDACT_JSON_STRICT","0") in ("1","true","TRUE","yes","YES")
cache_enabled = os.environ.get("TREND_CACHE","0") == "1"
cache_ttl = int(os.environ.get("TREND_CACHE_TTL","60") or "60")
cache_file = os.environ.get("TREND_CACHE_FILE","")

def redact_line(s: str) -> str:
    pats = [
        (re.compile(r'(?i)\\b([A-Za-z0-9_]*(password|passwd|token|api[_-]?key|secret|access[_-]?key|private[_-]?key|session([_-]?id)?|id[_-]?token|refresh[_-]?token|x[_-]?auth[_-]?token)[A-Za-z0-9_]*)=([^ \\t]+)'), r'\\1=REDACTED'),
        (re.compile(r'(?i)\\b(Authorization:|X-Auth-Token:)\\s+[^ \\t]+'), r'\\1 REDACTED'),
        (re.compile(r'(?i)\\b(Bearer)\\s+[A-Za-z0-9_.~+/-]+=*'), r'\\1 REDACTED'),
        (re.compile(r'\\b[0-9A-Za-z_-]{12,}\\.[0-9A-Za-z_-]{12,}\\.[0-9A-Za-z_-]{12,}\\b'), 'REDACTED_JWT'),
        (re.compile(r'\\bAKIA[0-9A-Z]{16}\\b'), 'AKIA_REDACTED'),
        (re.compile(r'\\bASIA[0-9A-Z]{16}\\b'), 'ASIA_REDACTED'),
        (re.compile(r'\\bgh[pousr]_[A-Za-z0-9]{20,}\\b'), 'GH_REDACTED'),
        (re.compile(r'\\bgithub_pat_[A-Za-z0-9_]{20,}\\b'), 'GH_PAT_REDACTED'),
        (re.compile(r'\\bxox[baprs]-[A-Za-z0-9-]{10,}\\b'), 'SLACK_REDACTED'),
        (re.compile(r'\\bAIza[0-9A-Za-z_-]{35}\\b'), 'GCP_REDACTED'),
        (re.compile(r'\\bya29\\.[A-Za-z0-9_-]{10,}\\b'), 'OAUTH_REDACTED'),
        (re.compile(r'-----BEGIN [A-Z ]*PRIVATE KEY-----'), '-----BEGIN PRIVATE KEY-----'),
        (re.compile(r'-----END [A-Z ]*PRIVATE KEY-----'), '-----END PRIVATE KEY-----'),
    ]
    out = s
    for pat, rep in pats:
        out = pat.sub(rep, out)
    return out

def redact_json_obj(obj):
    if isinstance(obj, dict):
        return {k: redact_json_obj(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [redact_json_obj(v) for v in obj]
    if isinstance(obj, str):
        if redact_json_strict:
            return "REDACTED"
        return redact_line(obj)
    return obj

if redact and not json_mode and not csv_mode:
    def print(*args, **kwargs):
        sep = kwargs.get("sep", " ")
        end = kwargs.get("end", "\\n")
        text = sep.join(str(a) for a in args)
        builtins.print(redact_line(text), end=end)

def c(s, code):
    if not color:
        return s
    return f"\033[{code}m{s}\033[0m"

def header(text):
    if not color:
        return text
    if text.startswith("=== ") and text.endswith(" ==="):
        inner = text[4:-4]
        return f"=== {c(inner, '1;36')} ==="
    return c(text, "1;36")

def color_kv(k, v):
    text = f"{k}={v}"
    if not color or int(v) == 0:
        return text
    if k == "CRIT":
        return c(text, "1;31")
    if k == "WARN":
        return c(text, "1;33")
    if k == "UNKNOWN":
        return c(text, "1;35")
    if k == "SKIP":
        return c(text, "1;36")
    if k == "OK":
        return c(text, "1;32")
    return text

def parse_date_arg(s: str, end_of_day: bool = False):
    if not s:
        return None
    fmts = ("%Y-%m-%d", "%Y-%m-%d_%H%M%S", "%Y-%m-%dT%H:%M:%S")
    for fmt in fmts:
        try:
            ts = time.strptime(s, fmt)
            epoch = int(time.mktime(ts))
            if fmt == "%Y-%m-%d" and end_of_day:
                epoch += 86399
            return epoch
        except Exception:
            continue
    raise ValueError(f"invalid date: {s} (use YYYY-MM-DD or YYYY-MM-DD_HHMMSS)")

try:
    since_ts = parse_date_arg(since_arg, end_of_day=False)
    until_ts = parse_date_arg(until_arg, end_of_day=True)
except ValueError as exc:
    print(f"ERROR: {exc}", file=sys.stderr)
    sys.exit(2)

pat = os.path.join(log_dir, 'full_health_monitor_summary_[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_[0-9][0-9][0-9][0-9][0-9][0-9].log')
all_files = glob.glob(pat)
file_rows = []
name_re = re.compile(r'full_health_monitor_summary_(\d{4}-\d{2}-\d{2})_(\d{6})\.log$')
for fp in all_files:
    m = name_re.search(os.path.basename(fp))
    if not m:
        continue
    try:
        ts = time.mktime(time.strptime(f"{m.group(1)} {m.group(2)}", "%Y-%m-%d %H%M%S"))
    except Exception:
        continue
    if since_ts is not None and ts < since_ts:
        continue
    if until_ts is not None and ts > until_ts:
        continue
    file_rows.append((ts, fp))
file_rows.sort(reverse=True)
files = [fp for _, fp in file_rows][:last_n]

if not files and not cache_enabled:
    if json_mode:
        print(json.dumps({
            'schema_version': 1,
            'trend_json_contract_version': 1,
            'runs': [],
            'totals': {'CRIT':0,'WARN':0,'UNKNOWN':0,'SKIP':0,'OK':0},
            'reasons': [],
            'anomaly': {
                'enabled': anomaly_enabled,
                'window': anomaly_window,
                'z_threshold': anomaly_z,
                'enough_data': False,
                'signals': [],
            },
        }, indent=2, sort_keys=True))
    elif csv_mode:
        print("file,CRIT,WARN,UNKNOWN,SKIP,OK")
    else:
        print(f'No summary artifacts found in: {log_dir}')
    sys.exit(0)

order=['CRIT','WARN','UNKNOWN','SKIP','OK']
overall={k:0 for k in order}
reason_counts={}
runs=[]
history_warnings=[]

def get_kv(line, key):
    m=re.search(rf"\b{re.escape(key)}=([^ ]+)", line)
    return m.group(1) if m else None

def parse_run_file(fp):
    rc={k:0 for k in order}
    had=False
    try:
        with open(fp,'r',encoding='utf-8',errors='ignore') as f:
            for line in f:
                line=line.strip()
                if not line.startswith('monitor='):
                    continue
                had=True
                row={}
                for tok in line.split():
                    if "=" not in tok:
                        return None, {"file": fp, "state": "malformed", "detail": "bad_token"}
                    key, val = tok.split("=", 1)
                    row[key] = val
                missing = [k for k in ("monitor","host","status") if k not in row]
                if missing:
                    return None, {"file": fp, "state": "malformed", "detail": "missing_" + "_".join(missing)}
                st=row["status"]
                if st not in rc:
                    return None, {"file": fp, "state": "malformed", "detail": "invalid_status"}
                rc[st]+=1
                overall[st]=overall.get(st,0)+1
                if st!='OK':
                    reason=row.get('reason')
                    if reason:
                        reason_counts[reason]=reason_counts.get(reason,0)+1
    except Exception:
        return None, {"file": fp, "state": "unreadable"}
    if not had:
        return None, {"file": fp, "state": "malformed", "detail": "no_monitor_lines"}
    return rc, None

cache_hit = False
if cache_enabled and cache_file and os.path.exists(cache_file):
    try:
        age = time.time() - os.path.getmtime(cache_file)
        if age <= cache_ttl:
            cached = json.load(open(cache_file, "r", encoding="utf-8"))
            if cached.get("last_n") == last_n and cached.get("source_dir") == log_dir and cached.get("since") == since_arg and cached.get("until") == until_arg and cached.get("anomaly_enabled") == anomaly_enabled and float(cached.get("anomaly_z", anomaly_z)) == anomaly_z and int(cached.get("anomaly_window", anomaly_window)) == anomaly_window:
                runs = cached.get("runs", [])
                overall = cached.get("totals", overall)
                reason_counts = {r["reason"]: r["count"] for r in cached.get("reasons", [])}
                history_warnings = cached.get("history_warnings", [])
                cache_hit = True
    except Exception:
        cache_hit = False

if not cache_hit:
    for fp in files:
        rc, warning = parse_run_file(fp)
        if warning:
            history_warnings.append(warning)
            continue
        runs.append({'file': fp, 'totals': rc})

rollup=sorted(reason_counts.items(), key=lambda kv: (-kv[1], kv[0]))

anomaly = {
    "enabled": anomaly_enabled,
    "window": anomaly_window,
    "z_threshold": anomaly_z,
    "enough_data": False,
    "signals": []
}
if anomaly_enabled:
    if len(runs) >= (anomaly_window + 1):
        anomaly["enough_data"] = True
        metrics = ["CRIT", "WARN", "UNKNOWN", "SKIP", "OK"]
        current = runs[0]["totals"] if runs else {}
        baseline_runs = runs[1:1+anomaly_window]
        for m in metrics:
            vals = [int((r.get("totals") or {}).get(m, 0) or 0) for r in baseline_runs]
            if not vals:
                continue
            mean = sum(vals) / float(len(vals))
            var = sum((v - mean) ** 2 for v in vals) / float(len(vals))
            std = var ** 0.5
            cur = int(current.get(m, 0) or 0)
            if std == 0:
                zscore = 999.0 if cur > mean else 0.0
            else:
                zscore = (cur - mean) / std
            is_anom = (zscore >= anomaly_z) and (cur > mean)
            anomaly["signals"].append({
                "metric": m,
                "current": cur,
                "baseline_mean": round(mean, 4),
                "baseline_std": round(std, 4),
                "zscore": round(zscore, 4),
                "anomalous": bool(is_anom)
            })
        anomaly["signals"].sort(key=lambda s: (-s["zscore"], s["metric"]))
if json_mode:
    out={'schema_version': 1, 'trend_json_contract_version': 1, 'runs':runs, 'totals':overall, 'reasons':[{'reason':r,'count':c} for r,c in rollup], 'anomaly': anomaly, 'history_warnings': history_warnings}
    if redact_json or redact_json_strict:
        out = redact_json_obj(out)
    print(json.dumps(out, indent=2, sort_keys=True))
elif csv_mode:
    print("file,CRIT,WARN,UNKNOWN,SKIP,OK")
    for r in runs:
        row = [os.path.basename(r["file"]), str(r["totals"].get("CRIT",0)), str(r["totals"].get("WARN",0)), str(r["totals"].get("UNKNOWN",0)), str(r["totals"].get("SKIP",0)), str(r["totals"].get("OK",0))]
        print(",".join(row))
else:
    print(header("=== linux-maint trend ==="))
    print(f'trend_runs={len(runs)} source_dir={log_dir}')
    print(c('totals:', "1;36") + ' ' + ' '.join(color_kv(k, overall.get(k,0)) for k in order))
    print('')
    print(c('runs:', "1;36"))
    for r in runs:
      print(f"- {os.path.basename(r['file'])}: " + ' '.join(color_kv(k, r['totals'].get(k,0)) for k in order))
    print('')
    print(c('reasons:', "1;36"))
    if rollup:
      for reason, count in rollup[:20]:
          print(f"{reason}={count}")
    else:
      print('none')
    if history_warnings:
      print('')
      print(c('history_warnings:', "1;36"))
      for warn in history_warnings[:20]:
          detail = warn.get("detail")
          msg = f"- skipped {warn.get('state','unknown')} history file: {warn.get('file','')}"
          if detail:
              msg += f" ({detail})"
          print(msg)
    if anomaly_enabled:
      print('')
      print(c('anomaly_signals:', "1;36"))
      if not anomaly.get("enough_data"):
          print(f"insufficient_data runs={len(runs)} required={anomaly_window + 1}")
      else:
          hot = [s for s in anomaly.get("signals", []) if s.get("anomalous")]
          if not hot:
              print("none")
          else:
              for s in hot:
                  print(f"{s['metric']}: current={s['current']} baseline_mean={s['baseline_mean']} zscore={s['zscore']}")
    print('')
    print("== Guidance ==")
    guidance = []
    if overall.get("CRIT", 0) or overall.get("WARN", 0) or overall.get("UNKNOWN", 0):
        guidance.extend(["linux-maint report --short", "linux-maint status --since 1d"])
    else:
        guidance.append("linux-maint run")
    if history_warnings:
        guidance.append("linux-maint status --since 1d")
    if anomaly_enabled:
        guidance.append("linux-maint trend --anomaly --last 10")
    seen = set()
    for step in guidance:
        if step in seen:
            continue
        seen.add(step)
        print(f"next_step: {step}")
    worst = "OK"
    for candidate in ("CRIT", "WARN", "UNKNOWN", "SKIP", "OK"):
        if overall.get(candidate, 0):
            worst = candidate
            break
    print('')
    print("== Summary ==")
    print(f"trend_runs={len(runs)}")
    print(f"history_warnings={len(history_warnings)}")
    print(f"result={worst}")
    suffix = {"OK":"ok","WARN":"warn","CRIT":"crit","UNKNOWN":"unknown","SKIP":"skip"}.get(worst, worst.lower())
    color_map = {"OK":"1;32","WARN":"1;33","CRIT":"1;31","UNKNOWN":"1;33","SKIP":"1;36"}
    print(c(f"trend {suffix}", color_map.get(worst, "1;33")))

if cache_enabled and cache_file and not cache_hit:
    try:
        payload = {
            "last_n": last_n,
            "since": since_arg,
            "until": until_arg,
            "source_dir": log_dir,
            "anomaly_enabled": anomaly_enabled,
            "anomaly_z": anomaly_z,
            "anomaly_window": anomaly_window,
            "created_epoch": int(time.time()),
            "runs": runs,
            "totals": overall,
            "reasons": [{"reason": r, "count": c} for r,c in rollup],
            "history_warnings": history_warnings,
        }
        with open(cache_file, "w", encoding="utf-8") as f:
            json.dump(payload, f, indent=2, sort_keys=True)
    except Exception:
        pass
PY
}

linux_maint_cmd_runtimes() {
    RT_JSON=0
    RT_LAST=1
    RT_COLOR=1
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --json) RT_JSON=1; shift ;;
        --last) RT_LAST="$2"; shift 2 ;;
        -h|--help)
          command_usage runtimes
          exit 0;;
        *) echo "Unknown runtimes flag: $1" >&2; exit 2;;
      esac
    done
    [[ -n "${NO_COLOR:-}" || -n "${LM_NO_COLOR:-}" ]] && RT_COLOR=0
    color_enabled || RT_COLOR=0

    if [[ ! "$RT_LAST" =~ ^[0-9]+$ ]] || [[ "$RT_LAST" -lt 1 ]]; then
      echo "ERROR: invalid --last '$RT_LAST' (use positive integer)" >&2
      exit 2
    fi

    if [[ "$MODE" == "repo" ]]; then
      log_dir="${LOG_DIR:-$REPO_LOG_DIR}"
    else
      log_dir="${LOG_DIR:-/var/log/health}"
    fi

    # Gather last N wrapper logs
    mapfile -t rt_files < <(find "$log_dir" -maxdepth 1 -type f -name 'full_health_monitor_[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_[0-9][0-9][0-9][0-9][0-9][0-9].log' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n "$RT_LAST" | awk '{print $2}')

    if [[ "${#rt_files[@]}" -eq 0 ]]; then
      echo "No wrapper logs found in $log_dir" >&2
      exit 1
    fi

    CFG_DIR="$(linux_maint_effective_cfg_dir)"
    MONITOR_RUNTIME_WARN_FILE="${MONITOR_RUNTIME_WARN_FILE:-$CFG_DIR/monitor_runtime_warn.conf}"
    RT_COLOR="$RT_COLOR" python3 - "$RT_JSON" "$log_dir" "$MONITOR_RUNTIME_WARN_FILE" "${rt_files[@]}" <<'PY'
import json, os, re, sys

json_mode = sys.argv[1] == "1"
log_dir = sys.argv[2]
warn_file = sys.argv[3]
files = sys.argv[4:]
color = os.environ.get("RT_COLOR", "1") == "1"
pat = re.compile(r'RUNTIME\s+monitor=([^ ]+)\s+ms=([0-9]+)')

def c(s, code):
    if not color:
        return s
    return f"\033[{code}m{s}\033[0m"

def final_label(cmd, result):
    mapping = {
        "OK": ("1;32", "ok"),
        "WARN": ("1;33", "warn"),
        "CRIT": ("1;31", "crit"),
        "UNKNOWN": ("1;33", "unknown"),
        "SKIP": ("1;36", "skip"),
    }
    code, word = mapping.get(result, ("1;33", str(result).lower()))
    return c(f"{cmd} {word}", code)

warn_ms = {}
if warn_file and os.path.exists(warn_file):
    with open(warn_file, "r", encoding="utf-8", errors="ignore") as fh:
        for raw in fh:
            line = raw.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            mon, secs = line.split("=", 1)
            mon = mon.strip()
            secs = secs.strip()
            if mon and secs.isdigit() and int(secs) > 0:
                warn_ms[mon] = int(secs) * 1000

rows = []
for f in files:
    try:
        with open(f, 'r', encoding='utf-8', errors='ignore') as fh:
            for line in fh:
                m = pat.search(line)
                if m:
                    rows.append({"monitor": m.group(1), "ms": int(m.group(2)), "unit": "ms", "source_file": f})
    except FileNotFoundError:
        continue

rows.sort(key=lambda r: (-r["ms"], r["monitor"]))

if json_mode:
    print(json.dumps({"schema_version": 1, "runtimes_json_contract_version": 1, "files": files, "unit": "ms", "rows": rows}, sort_keys=True))
    raise SystemExit(0)

print("=== linux-maint runtimes ===")
print(f"files={len(files)}")
print(f"log_dir={log_dir}")
warn_hits = 0
for row in rows:
    mon = row["monitor"]
    ms = row["ms"]
    line = f"monitor={mon} ms={ms}"
    if mon in warn_ms and ms >= warn_ms[mon]:
        warn_hits += 1
        line = c(line, "1;33")
    print(line)

result = "WARN" if warn_hits else "OK"
slowest = rows[0] if rows else {}
print("")
print("== Guidance ==")
if result == "WARN":
    print("next_step: linux-maint report --short")
    print("next_step: linux-maint runtimes --last 5")
else:
    print("next_step: linux-maint report --short")
print("")
print("== Summary ==")
print(f"files={len(files)}")
print(f"rows={len(rows)}")
print(f"warn_hits={warn_hits}")
if slowest:
    print(f"slowest_monitor={slowest.get('monitor','')}")
    print(f"slowest_ms={slowest.get('ms','')}")
print(f"result={result}")
print(final_label("runtimes", result))
PY
}

linux_maint_cmd_export() {
    EXPORT_JSON=0
    EXPORT_CSV=0
    EXPORT_JSONL=0
    case "${1:-}" in
      --json) EXPORT_JSON=1; shift ;;
      --csv) EXPORT_CSV=1; shift ;;
      --jsonl) EXPORT_JSONL=1; shift ;;
      -h|--help) EXPORT_JSON=0 ;;
      "") ;;
      *) echo "Unknown export flag: $1" >&2; exit 2 ;;
    esac

    if [[ "$EXPORT_JSON" -eq 0 && "$EXPORT_CSV" -eq 0 && "$EXPORT_JSONL" -eq 0 ]]; then
      echo "Usage: linux-maint export --json|--csv|--jsonl" >&2
      exit 2
    fi
    export_mode_count=$((EXPORT_JSON + EXPORT_CSV + EXPORT_JSONL))
    if [[ "$export_mode_count" -gt 1 ]]; then
      echo "ERROR: choose only one export format (--json, --csv, or --jsonl)" >&2
      exit 2
    fi

    if [[ "$MODE" == "repo" ]]; then
      summary_file="$REPO_SUMMARY_LATEST"
      status_file="$REPO_STATUS_FILE"
      log_file="$REPO_LATEST_LOG"
      summary_json="$REPO_SUMMARY_JSON_LATEST"
    else
      summary_file="$(linux_maint_reporting_summary_latest)"
      status_file="$(linux_maint_reporting_status_file)"
      log_file="$(linux_maint_reporting_latest_log)"
      summary_json="$(linux_maint_reporting_summary_json_latest)"
    fi

    python3 - "$MODE" "$EXPORT_CSV" "$EXPORT_JSONL" "$status_file" "$summary_file" "$summary_json" "$log_file" <<'PY'
import json, os, re, sys

mode = sys.argv[1]
csv_mode = sys.argv[2] == "1"
jsonl_mode = sys.argv[3] == "1"
status_path, summary_path, summary_json_path, log_path = sys.argv[4:8]
redact_json = os.environ.get("LM_REDACT_JSON","0") in ("1","true","TRUE","yes","YES")
redact_json_strict = os.environ.get("LM_REDACT_JSON_STRICT","0") in ("1","true","TRUE","yes","YES")

def read_kv(path):
    d={}
    if not path or not os.path.exists(path):
        return d
    try:
        with open(path,'r',encoding='utf-8',errors='ignore') as f:
            for line in f:
                line=line.strip()
                if not line or '=' not in line:
                    continue
                k,v=line.split('=',1)
                d[k]=v
    except Exception:
        return d
    return d

def parse_kv_line(line):
    d={}
    for p in line.strip().split():
        if '=' in p:
            k,v=p.split('=',1)
            d[k]=v
    return d

def redact_value(val: str) -> str:
    lower = val.lower()
    secret_keys = (
        "password","passwd","token","api_key","apikey","secret",
        "access_key","private_key","session","session_id","id_token",
        "refresh_token","x_auth_token"
    )
    if any(k in lower for k in secret_keys):
        return "REDACTED"
    if val.count(".") == 2 and all(len(p) >= 12 for p in val.split(".")):
        return "REDACTED_JWT"
    if re.match(r'^(gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|xox[baprs]-[A-Za-z0-9-]{10,})$', val):
        return "REDACTED"
    if re.match(r'^AIza[0-9A-Za-z_-]{35}$', val):
        return "GCP_REDACTED"
    if re.match(r'^ya29\.[A-Za-z0-9_-]{10,}$', val):
        return "OAUTH_REDACTED"
    return val

def redact_kv_map(row):
    out = {}
    for k,v in row.items():
        if redact_json_strict:
            out[k] = "REDACTED"
            continue
        kl = k.lower()
        if any(x in kl for x in ("password","passwd","token","api_key","apikey","secret","access_key","private_key","session","id_token","refresh_token","x_auth_token")):
            out[k] = "REDACTED"
        else:
            out[k] = redact_value(v)
    return out

def read_rows():
    if summary_json_path and os.path.exists(summary_json_path):
        try:
            with open(summary_json_path,'r',encoding='utf-8',errors='ignore') as f:
                payload=json.load(f)
            if isinstance(payload, dict):
                rows = payload.get('rows')
                if not isinstance(rows, list):
                    print(f"ERROR: export requires valid summary JSON rows at {summary_json_path}", file=sys.stderr)
                    raise SystemExit(2)
                meta = payload.get('meta', {})
                if meta is None:
                    meta = {}
                if not isinstance(meta, dict):
                    print(f"ERROR: export requires valid summary JSON meta at {summary_json_path}", file=sys.stderr)
                    raise SystemExit(2)
                return rows, meta
            if isinstance(payload, list):
                return payload, {}
        except Exception:
            print(f"ERROR: export requires valid summary JSON at {summary_json_path}", file=sys.stderr)
            raise SystemExit(2)
        print(f"ERROR: export requires supported summary JSON shape at {summary_json_path}", file=sys.stderr)
        raise SystemExit(2)
    rows=[]
    if summary_path and os.path.exists(summary_path):
        try:
            with open(summary_path,'r',encoding='utf-8',errors='ignore') as f:
                for line in f:
                    if line.startswith('monitor='):
                        rows.append(parse_kv_line(line))
        except Exception:
            print(f"ERROR: export requires readable summary log at {summary_path}", file=sys.stderr)
            raise SystemExit(2)
    return rows, {}

def parse_allowlist():
    raw=os.environ.get("LM_EXPORT_ALLOWLIST","").strip()
    if not raw:
        return None
    parts=[p for p in re.split(r'[,\s]+', raw) if p]
    if not parts:
        return None
    allow=set(parts)
    # Always keep core identity fields in rows.
    allow.update(["monitor","host","status","reason"])
    return allow

def filter_map(d, allow):
    if not d:
        return d
    return {k:v for k,v in d.items() if k in allow}

def parse_log_summary(log_path):
    summary_result=None
    summary_hosts=None
    if not log_path or not os.path.exists(log_path):
        return summary_result, summary_hosts
    try:
        with open(log_path,'r',encoding='utf-8',errors='ignore') as f:
            for line in f:
                if 'SUMMARY_RESULT' in line:
                    m=re.search(r'SUMMARY_RESULT\\s+(.*)$', line)
                    if m:
                        summary_result=parse_kv_line(m.group(1))
                elif 'SUMMARY_HOSTS' in line:
                    m=re.search(r'SUMMARY_HOSTS\\s+(.*)$', line)
                    if m:
                        summary_hosts=parse_kv_line(m.group(1))
    except Exception:
        return None, None
    return summary_result, summary_hosts

def worst_status(rows):
    order={'OK':0,'WARN':1,'CRIT':2,'UNKNOWN':3,'SKIP':3}
    worst='OK'
    for r in rows:
        st=r.get('status','UNKNOWN')
        if order.get(st,3) >= order.get(worst,0):
            worst=st
    return worst

def derive_hosts(rows):
    counts={'ok':0,'warn':0,'crit':0,'unknown':0,'skipped':0}
    for r in rows:
        st=(r.get('status') or 'UNKNOWN').upper()
        if st == 'OK':
            counts['ok']+=1
        elif st == 'WARN':
            counts['warn']+=1
        elif st == 'CRIT':
            counts['crit']+=1
        elif st == 'SKIP':
            counts['skipped']+=1
        else:
            counts['unknown']+=1
    return counts

rows, meta = read_rows()
if os.environ.get("LM_REDACT_LOGS","0") in ("1","true","TRUE","yes","YES") or redact_json or redact_json_strict:
    rows = [redact_kv_map(r) for r in rows]
    if meta:
        meta = redact_kv_map(meta)

allow = parse_allowlist()
if allow:
    rows = [filter_map(r, allow) for r in rows]
    if meta:
        meta = filter_map(meta, allow)
summary_result, summary_hosts = parse_log_summary(log_path)

summary_result_source = 'log' if summary_result else 'derived'
summary_hosts_source = 'log' if summary_hosts else 'derived'

if not summary_result:
    summary_result={'overall': worst_status(rows), 'derived': True}
if not summary_hosts:
    summary_hosts=derive_hosts(rows)
    summary_hosts['derived'] = True

last_status = read_kv(status_path)
if allow:
    last_status = filter_map(last_status, allow)
if redact_json or redact_json_strict:
    last_status = redact_kv_map(last_status)

if csv_mode:
    import csv
    writer = csv.writer(sys.stdout)
    writer.writerow(["monitor","host","status","reason"])
    for r in rows:
        writer.writerow([
            r.get("monitor",""),
            r.get("host",""),
            r.get("status",""),
            r.get("reason",""),
        ])
elif jsonl_mode:
    for r in rows:
        print(json.dumps(r, sort_keys=True))
else:
    out={
        'schema_version': 1,
        'export_json_contract_version': 1,
        'mode': mode,
        'summary_file': summary_path if summary_path and os.path.exists(summary_path) else None,
        'summary_log': log_path if log_path and os.path.exists(log_path) else None,
        'summary_json': summary_json_path if summary_json_path and os.path.exists(summary_json_path) else None,
        'summary_result_source': summary_result_source,
        'summary_hosts_source': summary_hosts_source,
        'summary_result': summary_result,
        'summary_hosts': summary_hosts,
        'last_status': last_status,
        'rows': rows,
    }
    if meta:
        out['meta']=meta

    print(json.dumps(out, indent=2, sort_keys=True))
PY
}
