#!/usr/bin/env bash
# History and run-index command helpers for linux-maint.

linux_maint_cmd_history() {
    local LAST_N=10
    local HISTORY_JSON=0
    local HISTORY_TABLE=0
    local HISTORY_COLOR=1
    local HISTORY_COMPACT=0
    local HISTORY_NOTE=""
    local HISTORY_SQLITE=0
    case "${LM_HISTORY_SQLITE:-0}" in
      1|true|TRUE|yes|YES|on|ON) HISTORY_SQLITE=1 ;;
    esac
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --last) LAST_N="$2"; shift 2;;
        --json) HISTORY_JSON=1; shift 1;;
        --table) HISTORY_TABLE=1; shift 1;;
        --no-color) HISTORY_COLOR=0; shift 1;;
        --compact) HISTORY_COMPACT=1; shift 1;;
        --sqlite) HISTORY_SQLITE=1; shift 1;;
        -h|--help)
          command_usage history
          exit 0;;
        *) echo "Unknown history flag: $1" >&2; exit 2;;
      esac
    done
    [[ -n "${NO_COLOR:-}" || -n "${LM_NO_COLOR:-}" ]] && HISTORY_COLOR=0
    color_enabled || HISTORY_COLOR=0

    if [[ ! "$LAST_N" =~ ^[0-9]+$ ]] || (( LAST_N <= 0 )); then
      echo "ERROR: --last must be a positive integer" >&2
      exit 2
    fi

    local state_dir history_run_cmd history_db index_file alt
    state_dir="$(linux_maint_effective_state_dir)"
    if [[ "$MODE" == "repo" ]]; then
      history_run_cmd="linux-maint run"
    else
      history_run_cmd="sudo linux-maint run"
    fi
    history_db="${LM_HISTORY_DB:-$state_dir/run_index.sqlite}"
    index_file="${LM_RUN_INDEX_FILE:-$state_dir/run_index.jsonl}"

    if [[ "$HISTORY_SQLITE" -eq 1 && -f "$history_db" ]]; then
      LM_COLOR="$HISTORY_COLOR" HISTORY_NOTE="$HISTORY_NOTE" python3 - "$history_db" "$LAST_N" "$HISTORY_JSON" "$HISTORY_TABLE" "$HISTORY_COMPACT" <<'PY'
import json, os, sqlite3, sys
db_path, last_n, json_mode, table, compact = sys.argv[1:6]
last_n = int(last_n)
json_mode = json_mode == "1"
table = table == "1"
compact = compact == "1"
color = os.environ.get("LM_COLOR","1") == "1"
note = os.environ.get("HISTORY_NOTE","")

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

if not os.path.exists(db_path):
    print(f"No sqlite history db found: {db_path}")
    raise SystemExit(1)

conn = sqlite3.connect(db_path)
cur = conn.cursor()
cur.execute("""SELECT run_id,timestamp,overall,exit_code,hosts_crit,hosts_warn,hosts_unknown,hosts_skipped,hosts_ok
               FROM runs ORDER BY ts_epoch DESC LIMIT ?""", (last_n,))
rows = cur.fetchall()
conn.close()
runs = []
for row in rows:
    run_id, ts, overall, exit_code, crit, warn, unknown, skipped, ok = row
    runs.append({
        "run_index_version": 1,
        "run_id": run_id,
        "timestamp": ts,
        "overall": overall,
        "exit_code": exit_code,
        "hosts": {
            "crit": int(crit or 0),
            "warn": int(warn or 0),
            "unknown": int(unknown or 0),
            "skipped": int(skipped or 0),
            "ok": int(ok or 0),
        },
    })

if json_mode:
    print(json.dumps({
        "schema_version": 1,
        "history_json_contract_version": 1,
        "source": "sqlite",
        "invalid_lines": 0,
        "runs": runs,
    }, indent=2, sort_keys=True))
    raise SystemExit(0)
if compact:
    if runs:
        r = runs[0]
        h = r.get("hosts",{})
        print(f"last_run={r.get('timestamp','')} overall={color_status(r.get('overall','UNKNOWN'))} CRIT={h.get('crit',0)} WARN={h.get('warn',0)} UNKNOWN={h.get('unknown',0)} SKIP={h.get('skipped',0)} OK={h.get('ok',0)}")
    else:
        print("no runs")
    raise SystemExit(0)
if not runs:
    print(header("=== Last 0 runs (sqlite) ==="))
    print("No runs recorded yet.")
    raise SystemExit(0)

print(header(f"=== Last {len(runs)} runs (sqlite) ==="))
if note:
    print(note)
if table:
    headers=("TIMESTAMP","OVERALL","EXIT_CODE","CRIT","WARN","UNKNOWN","SKIP","OK")
    rows2=[]
    for r in runs:
        h=r.get("hosts",{})
        rows2.append((str(r.get("timestamp","")), str(r.get("overall","UNKNOWN")), str(r.get("exit_code","")), str(h.get("crit",0)), str(h.get("warn",0)), str(h.get("unknown",0)), str(h.get("skipped",0)), str(h.get("ok",0))))
    w=[len(h) for h in headers]
    for rr in rows2:
        for i,v in enumerate(rr):
            w[i]=max(w[i], len(v))
    print(" ".join(f"{headers[i]:<{w[i]}}" for i in range(len(headers))))
    for rr in rows2:
        cells=[f"{rr[i]:<{w[i]}}" for i in range(len(headers))]
        cells[1]=color_status(rr[1], cells[1])
        print(" ".join(cells))
else:
    for r in runs:
        h=r.get("hosts",{})
        print(f"{r.get('timestamp','')} overall={color_status(r.get('overall','UNKNOWN'))} exit_code={r.get('exit_code','')} CRIT={h.get('crit',0)} WARN={h.get('warn',0)} UNKNOWN={h.get('unknown',0)} SKIP={h.get('skipped',0)} OK={h.get('ok',0)}")
latest = runs[0]
latest_overall = latest.get("overall", "UNKNOWN")
print("")
print("== Guidance ==")
if latest_overall != "OK":
    print("next_step: linux-maint report --short")
    print("next_step: linux-maint status --verbose")
else:
    print("next_step: linux-maint run")
print("")
print("== Summary ==")
print(f"history_runs={len(runs)}")
print("source=sqlite")
print(f"latest_overall={latest_overall}")
print(f"result={latest_overall}")
print(final_label("history", latest_overall))
PY
      exit 0
    fi

    HISTORY_NOTE=""
    if [[ ! -f "$index_file" && -z "${LM_RUN_INDEX_FILE:-}" && -z "${LM_STATE_DIR:-}" ]]; then
      for alt in /var/tmp/run_index.jsonl /var/tmp/linux_maint/run_index.jsonl /tmp/linux_maint/run_index.jsonl; do
        if [[ -f "$alt" ]]; then
          index_file="$alt"
          HISTORY_NOTE="note: using run_index from $alt"
          break
        fi
      done
    fi

    LM_COLOR="$HISTORY_COLOR" HISTORY_NOTE="$HISTORY_NOTE" HISTORY_RUN_CMD="$history_run_cmd" python3 - "$index_file" "$LAST_N" "$HISTORY_JSON" "$HISTORY_TABLE" "$HISTORY_COMPACT" <<'PY'
import json, os, sys
from collections import deque
path, last_n, json_mode, table, compact = sys.argv[1:6]
last_n = int(last_n)
json_mode = json_mode == "1"
table = table == "1"
compact = compact == "1"
color = os.environ.get("LM_COLOR","1") == "1"
note = os.environ.get("HISTORY_NOTE","")
run_cmd = os.environ.get("HISTORY_RUN_CMD", "sudo linux-maint run")

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

def color_count(label, value):
    text = f"{label}={value}"
    if not color:
        return text
    try:
        v = int(value)
    except Exception:
        v = 0
    if v == 0:
        return text
    if label == "CRIT":
        return c(text, "1;31")
    if label == "WARN":
        return c(text, "1;33")
    if label == "OK":
        return c(text, "1;32")
    if label == "UNKNOWN":
        return c(text, "1;35")
    if label == "SKIP":
        return c(text, "1;36")
    return text

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

if not os.path.exists(path):
    print(c(f"No run index found: {path}", "1;31"))
    print(c("Hints:", "1;33"))
    print(c(f"- Run: {run_cmd}", "1;33"))
    print(c("- Or set LM_RUN_INDEX_FILE when invoking the wrapper", "1;33"))
    sys.exit(1)

rows=deque(maxlen=last_n)
invalid_lines = 0
with open(path, "r", encoding="utf-8", errors="ignore") as f:
    for line in f:
        line=line.strip()
        if not line:
            continue
        try:
            rows.append(json.loads(line))
        except Exception:
            invalid_lines += 1

if invalid_lines:
    print(f"ERROR: history requires valid JSON lines in run index: {path} (invalid_lines={invalid_lines})", file=sys.stderr)
    raise SystemExit(2)

rows = list(rows)
if json_mode:
    out = {
        "schema_version": 1,
        "history_json_contract_version": 1,
        "source": "run_index",
        "invalid_lines": invalid_lines,
        "runs": rows,
    }
    print(json.dumps(out, indent=2, sort_keys=True))
    raise SystemExit(0)

if compact:
    if rows:
        r = rows[-1]
        hosts = r.get("hosts",{}) or {}
        overall = r.get("overall","UNKNOWN")
        ov = color_status(overall)
        counts = [
            color_count("CRIT", hosts.get("crit",0)),
            color_count("WARN", hosts.get("warn",0)),
            color_count("UNKNOWN", hosts.get("unknown",0)),
            color_count("SKIP", hosts.get("skipped",0)),
            color_count("OK", hosts.get("ok",0)),
        ]
        print(f"last_run={r.get('timestamp','')} overall={ov} " + " ".join(counts))
    else:
        print("no runs")
    raise SystemExit(0)

if not rows:
    print(header("=== Last 0 runs (run_index) ==="))
    print("No runs recorded yet.")
    print(c(f"Hint: run {run_cmd}", "1;33"))
    raise SystemExit(0)

print(header(f"=== Last {len(rows)} runs (run_index) ==="))
if note:
    print(note)
if table:
    headers=("TIMESTAMP","OVERALL","EXIT_CODE","CRIT","WARN","UNKNOWN","SKIP","OK")
    table_rows=[]
    for r in rows:
        hosts = r.get("hosts",{}) or {}
        table_rows.append((
            r.get("timestamp",""),
            r.get("overall","UNKNOWN"),
            str(r.get("exit_code","")),
            str(hosts.get("crit",0)),
            str(hosts.get("warn",0)),
            str(hosts.get("unknown",0)),
            str(hosts.get("skipped",0)),
            str(hosts.get("ok",0)),
        ))
    w=[len(h) for h in headers]
    for row in table_rows:
        for i,v in enumerate(row):
            w[i]=max(w[i], len(v))
    def pad(s, width):
        return f"{s:<{width}}"
    print(" ".join(pad(headers[i], w[i]) for i in range(len(headers))))
    for row in table_rows:
        cells=[pad(row[i], w[i]) for i in range(len(headers))]
        overall=row[1]
        cells[1]=color_status(overall, cells[1])
        if row[3] != "0":
            cells[3]=c(cells[3],"1;31")
        if row[4] != "0":
            cells[4]=c(cells[4],"1;33")
        if row[5] != "0":
            cells[5]=c(cells[5],"1;35")
        if row[6] != "0":
            cells[6]=c(cells[6],"1;36")
        if row[7] != "0":
            cells[7]=c(cells[7],"1;32")
        print(" ".join(cells))
else:
    for r in rows:
        ts = r.get("timestamp","")
        overall = r.get("overall","UNKNOWN")
        exit_code = r.get("exit_code","")
        hosts = r.get("hosts",{}) or {}
        counts = " ".join([
            color_count("CRIT", hosts.get("crit",0)),
            color_count("WARN", hosts.get("warn",0)),
            color_count("UNKNOWN", hosts.get("unknown",0)),
            color_count("SKIP", hosts.get("skipped",0)),
            color_count("OK", hosts.get("ok",0)),
        ])
        print(f"{ts} overall={color_status(overall)} exit_code={exit_code} {counts}")
latest = rows[-1]
latest_overall = latest.get("overall", "UNKNOWN")
print("")
print("== Guidance ==")
if latest_overall != "OK":
    print("next_step: linux-maint report --short")
    print("next_step: linux-maint status --verbose")
else:
    print("next_step: linux-maint run")
print("")
print("== Summary ==")
print(f"history_runs={len(rows)}")
print("source=run_index")
print(f"latest_overall={latest_overall}")
print(f"result={latest_overall}")
print(final_label("history", latest_overall))
PY
}

linux_maint_cmd_run_index() {
    local ACTION="stats"
    local KEEP=200
    local RI_JSON=0
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --stats) ACTION="stats"; shift 1;;
        --prune) ACTION="prune"; shift 1;;
        --keep) KEEP="$2"; shift 2;;
        --json) RI_JSON=1; shift 1;;
        -h|--help)
          command_usage run-index
          exit 0;;
        *) echo "Unknown run-index flag: $1" >&2; exit 2;;
      esac
    done

    if [[ ! "$KEEP" =~ ^[0-9]+$ ]] || (( KEEP <= 0 )); then
      echo "ERROR: --keep must be a positive integer" >&2
      exit 2
    fi

    if [[ "$MODE" == "installed" && "$ACTION" == "prune" ]]; then
      need_root_for run-index
    fi

    local state_dir index_file alt
    if [[ "$MODE" == "repo" ]]; then
      state_dir="${LM_STATE_DIR:-$REPO_LOG_DIR}"
    else
      state_dir="${LM_STATE_DIR:-/var/lib/linux_maint}"
    fi
    index_file="${LM_RUN_INDEX_FILE:-$state_dir/run_index.jsonl}"
    if [[ ! -f "$index_file" && -z "${LM_RUN_INDEX_FILE:-}" && -z "${LM_STATE_DIR:-}" ]]; then
      for alt in /var/tmp/run_index.jsonl /var/tmp/linux_maint/run_index.jsonl /tmp/linux_maint/run_index.jsonl; do
        if [[ -f "$alt" ]]; then
          index_file="$alt"
          break
        fi
      done
    fi

    python3 - "$index_file" "$ACTION" "$KEEP" "$RI_JSON" <<'PY'
import json, os, sys, tempfile
path, action, keep_s, json_mode = sys.argv[1:5]
keep = int(keep_s)
json_mode = json_mode == "1"

def emit_json(payload):
    out = {
        "schema_version": 1,
        "run_index_command_json_contract_version": 1,
        "action": action,
    }
    out.update(payload)
    print(json.dumps(out, indent=2, sort_keys=True))

exists = os.path.exists(path)
if not exists:
    if json_mode:
        emit_json({"exists": False, "path": path, "error": "not_found"})
    else:
        print(f"No run index found: {path}")
    sys.exit(1)

entries = []
invalid = 0
with open(path, "r", encoding="utf-8", errors="ignore") as f:
    for raw in f:
        raw = raw.strip()
        if not raw:
            continue
        try:
            entries.append(json.loads(raw))
        except Exception:
            invalid += 1

count = len(entries)
last = entries[-1] if entries else {}

if action == "prune":
    if invalid:
        if json_mode:
            emit_json({
                "exists": True,
                "path": path,
                "total_before": count,
                "invalid_lines": invalid,
                "error": "invalid_lines",
                "message": "run-index prune requires valid JSON lines",
            })
        else:
            print(
                f"ERROR: run-index prune requires valid JSON lines in {path} "
                f"(invalid_lines={invalid})",
                file=sys.stderr,
            )
        sys.exit(2)
    if keep > 0 and count > keep:
        entries = entries[-keep:]
    try:
        tmp_dir = os.path.dirname(path) or "."
        fd, tmp = tempfile.mkstemp(prefix=".run_index.", dir=tmp_dir)
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            for e in entries:
                f.write(json.dumps(e, sort_keys=True) + "\n")
        os.replace(tmp, path)
    except Exception as exc:
        if json_mode:
            emit_json({
                "exists": True,
                "path": path,
                "kept": min(count, keep),
                "total_before": count,
                "invalid_lines": invalid,
                "error": "write_failed",
                "message": str(exc),
            })
        else:
            print(f"ERROR: run-index prune failed for {path}: {exc}", file=sys.stderr)
        sys.exit(2)
    if json_mode:
        emit_json({"exists": True, "path": path, "kept": min(count, keep), "total_before": count, "invalid_lines": invalid})
    else:
        msg = f"run_index_pruned path={path} kept={min(count, keep)} total_before={count}"
        if invalid:
            msg += f" invalid_lines={invalid}"
        print(msg)
    sys.exit(0)

if json_mode:
    emit_json({
        "exists": True,
        "path": path,
        "count": count,
        "last": last,
        "invalid_lines": invalid,
    })
else:
    print(f"run_index path={path} count={count}")
    if last:
        ts = last.get("timestamp","")
        overall = last.get("overall","")
        code = last.get("exit_code","")
        print(f"last_run timestamp={ts} overall={overall} exit_code={code}")
PY
}
