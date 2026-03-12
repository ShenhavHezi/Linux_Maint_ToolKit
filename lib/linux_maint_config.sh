#!/usr/bin/env bash
# Config and check command helpers for linux-maint.

linux_maint_cmd_config() {
    local CFG_JSON=0
    local CFG_SOURCES=0
    local CFG_LINT=0
    local CFG_DIFF_DEFAULTS=0
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --json) CFG_JSON=1; shift 1;;
        --sources) CFG_SOURCES=1; shift 1;;
        --lint) CFG_LINT=1; shift 1;;
        --diff-defaults) CFG_DIFF_DEFAULTS=1; shift 1;;
        -h|--help)
          command_usage config
          exit 0;;
        *) echo "Unknown config flag: $1" >&2; exit 2;;
      esac
    done

    local CFG_DIR CFG_INIT_CMD LOG_DIR_LOCAL SUMMARY_DIR_LOCAL STATE_DIR_LOCAL DOCTOR_STRICT main_conf conf_d
    local conf_files unreadable_conf_files f msg
    conf_files=()
    unreadable_conf_files=()
    CFG_DIR="$(linux_maint_effective_cfg_dir)"
    LOG_DIR_LOCAL="$(linux_maint_effective_log_dir)"
    SUMMARY_DIR_LOCAL="$(linux_maint_effective_summary_dir)"
    STATE_DIR_LOCAL="$(linux_maint_effective_state_dir)"
    if [[ "$MODE" == "repo" ]]; then
      CFG_INIT_CMD="linux-maint init"
    else
      CFG_INIT_CMD="sudo linux-maint init"
    fi
    DOCTOR_STRICT=0
    if [[ "${LM_STRICT:-0}" == "1" || "${LM_STRICT:-}" == "true" ]]; then
      DOCTOR_STRICT=1
    fi
    main_conf="$CFG_DIR/linux-maint.conf"
    conf_d="$CFG_DIR/conf.d"
    [[ -f "$main_conf" ]] && conf_files+=("$main_conf")
    if [[ -d "$conf_d" ]]; then
      while IFS= read -r f; do
        [[ -f "$f" ]] && conf_files+=("$f")
      done < <(find "$conf_d" -maxdepth 1 -type f -name '*.conf' 2>/dev/null | sort)
    fi

    if [[ "${#conf_files[@]}" -eq 0 ]]; then
      if [[ "$CFG_JSON" -eq 1 ]]; then
        printf '{\n'
        printf '  "schema_version": 1,\n'
        printf '  "config_json_contract_version": 1,\n'
        printf '  "cfg_dir": "%s",\n' "$CFG_DIR"
        printf '  "sources": [],\n'
        printf '  "error": "no_config",\n'
        printf '  "message": "No config files found"\n'
        printf '}\n'
        echo "Hint: $CFG_INIT_CMD" >&2
      else
        if color_enabled; then
          echo "${C_RED}No config files found in ${CFG_DIR}${C_RESET}"
        else
          echo "No config files found in $CFG_DIR"
        fi
        hint_line "$CFG_INIT_CMD"
      fi
      exit 1
    fi

    for f in "${conf_files[@]}"; do
      [[ -r "$f" ]] || unreadable_conf_files+=("$f")
    done
    if [[ "${#unreadable_conf_files[@]}" -gt 0 ]]; then
      msg="Cannot read config file(s)"
      if [[ "$CFG_JSON" -eq 1 ]]; then
        UNREADABLE_FILES="$(printf '%s\n' "${unreadable_conf_files[@]}")" CFG_DIR="$CFG_DIR" python3 - "${conf_files[@]}" <<'PY'
import json, os, sys
files = sys.argv[1:]
unreadable = [line for line in os.environ.get("UNREADABLE_FILES", "").splitlines() if line]
print(json.dumps({
    "schema_version": 1,
    "config_json_contract_version": 1,
    "cfg_dir": os.environ.get("CFG_DIR", "/etc/linux_maint"),
    "sources": files,
    "error": "unreadable_sources",
    "message": "Cannot read config file(s)",
    "unreadable_sources": unreadable,
}, indent=2, sort_keys=True))
PY
      else
        echo "ERROR: $msg" >&2
        for f in "${unreadable_conf_files[@]}"; do
          echo "- $f" >&2
        done
      fi
      exit 1
    fi

    local CFG_COLOR=1
    [[ -n "${NO_COLOR:-}" || -n "${LM_NO_COLOR:-}" ]] && CFG_COLOR=0
    color_enabled || CFG_COLOR=0
    CFG_DIR="$CFG_DIR" CFG_SOURCES="$CFG_SOURCES" CFG_JSON="$CFG_JSON" CFG_LINT="$CFG_LINT" CFG_DIFF_DEFAULTS="$CFG_DIFF_DEFAULTS" CFG_COLOR="$CFG_COLOR" REPO_ROOT="$REPO_ROOT" SHARE="$SHARE" python3 - "${conf_files[@]}" <<'PY'
import json, os, re, shlex, subprocess, sys

cfg_dir = os.environ.get("CFG_DIR", "/etc/linux_maint")
show_sources = os.environ.get("CFG_SOURCES", "0") == "1"
json_mode = os.environ.get("CFG_JSON", "0") == "1"
lint_mode = os.environ.get("CFG_LINT", "0") == "1"
diff_defaults = os.environ.get("CFG_DIFF_DEFAULTS", "0") == "1"
color = os.environ.get("CFG_COLOR", "0") == "1"
files = sys.argv[1:]

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

def extract_keys(paths):
    keys = []
    seen = set()
    for p in paths:
        try:
            with open(p, "r", encoding="utf-8", errors="ignore") as f:
                for raw in f:
                    line = raw.strip()
                    if not line or line.startswith("#"):
                        continue
                    m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\s*=", line)
                    if not m:
                        continue
                    k = m.group(1)
                    if k not in seen:
                        seen.add(k)
                        keys.append(k)
        except FileNotFoundError:
            continue
    return keys

def lint(paths):
    invalid = []
    seen = {}
    for p in paths:
        try:
            with open(p, "r", encoding="utf-8", errors="ignore") as f:
                for i, raw in enumerate(f, start=1):
                    line = raw.strip()
                    if not line or line.startswith("#"):
                        continue
                    if line.startswith("export "):
                        line = line[len("export "):].lstrip()
                    m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\s*=", line)
                    if not m:
                        invalid.append((p, i, raw.rstrip()))
                        continue
                    k = m.group(1)
                    seen.setdefault(k, []).append((p, i))
        except FileNotFoundError:
            continue
    duplicates = {k: v for k, v in seen.items() if len(v) > 1}
    return invalid, duplicates

def parse_defaults(paths):
    defaults = {}
    for p in paths:
        if not p or not os.path.exists(p):
            continue
        try:
            with open(p, "r", encoding="utf-8", errors="ignore") as f:
                for raw in f:
                    line = raw.strip()
                    if not line or line.startswith("##"):
                        continue
                    if line.startswith("#"):
                        line = line[1:].lstrip()
                    if line.startswith("export "):
                        line = line[len("export "):].lstrip()
                    m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\s*=", line)
                    if not m:
                        continue
                    k = m.group(1)
                    val = line.split("=", 1)[1].strip()
                    val = val.strip('"').strip("'")
                    defaults[k] = val
        except FileNotFoundError:
            continue
    return defaults

def find_defaults_template():
    candidates = [
        os.path.join(cfg_dir, "linux-maint.conf.example"),
        os.path.join(os.environ.get("REPO_ROOT", ""), "etc", "linux_maint", "linux-maint.conf.example"),
        os.path.join(os.environ.get("SHARE", ""), "templates", "linux_maint", "linux-maint.conf.example"),
        "/usr/local/share/linux_maint/templates/linux_maint/linux-maint.conf.example",
        "/usr/share/linux_maint/templates/linux_maint/linux-maint.conf.example",
    ]
    for p in candidates:
        if p and os.path.exists(p):
            return p
    return ""

BOOL_KEYS = {
    "LM_LOCAL_ONLY",
    "LM_SSH_ALLOWLIST_STRICT",
    "LM_DARK_SITE",
    "LM_REDACT_JSON",
    "LM_REDACT_JSON_STRICT",
    "LM_NOTIFY",
    "LM_NOTIFY_ONLY_ON_CHANGE",
}
INT_KEYS = {
    "LM_MAX_PARALLEL",
    "LM_SSH_RETRY",
    "MONITOR_TIMEOUT_SECS",
    "LM_LAST_RUN_MAX_AGE_MIN",
}
LIST_KEYS = {
    "LM_NOTIFY_TO",
    "LM_PREFLIGHT_OPT_CMDS",
}

def is_bool(val: str) -> bool:
    return val.lower() in {"1", "0", "true", "false", "yes", "no", "on", "off"}

def is_int(val: str) -> bool:
    return val.isdigit()

def parse_list(val: str):
    if not val.strip():
        return []
    if "," in val:
        return [p.strip() for p in val.split(",") if p.strip()]
    return [p for p in val.split() if p]

def is_list(val: str) -> bool:
    parts = parse_list(val)
    if not parts:
        return True
    for p in parts:
        if not re.match(r"^[A-Za-z0-9_.:/@+-]+$", p):
            return False
    return True

def validate_types(values):
    errors = []
    for k in BOOL_KEYS:
        if k in values:
            v = str(values.get(k, ""))
            if v == "" or not is_bool(v):
                errors.append({"key": k, "expected": "bool", "value": v})
    for k in INT_KEYS:
        if k in values:
            v = str(values.get(k, ""))
            if v == "" or not is_int(v):
                errors.append({"key": k, "expected": "int", "value": v})
    for k in LIST_KEYS:
        if k in values:
            v = str(values.get(k, ""))
            if not is_list(v):
                errors.append({"key": k, "expected": "list", "value": v})
    return errors

if lint_mode:
    invalid, duplicates = lint(files)
    print(header("=== linux-maint config lint ==="))
    print(f"cfg_dir={cfg_dir}")
    if invalid:
        print(c("\ninvalid lines:", "1;33"))
        for p, i, line in invalid[:50]:
            print(f"- {p}:{i}: {line}")
    else:
        print(c("\ninvalid lines: none", "1;32"))
    if duplicates:
        print(c("\nduplicate keys:", "1;33"))
        for k, locs in sorted(duplicates.items()):
            loc_str = ", ".join(f"{p}:{i}" for p, i in locs[:6])
            print(f"- {k}: {loc_str}")
    else:
        print(c("\nduplicate keys: none", "1;32"))
    if invalid or duplicates:
        sys.exit(1)
    sys.exit(0)

keys = extract_keys(files)
if not keys:
    if json_mode:
        print(json.dumps({
            "schema_version": 1,
            "config_json_contract_version": 1,
            "error": "no_keys",
            "cfg_dir": cfg_dir,
            "sources": files,
        }, indent=2, sort_keys=True))
    else:
        print(f"No config keys found in {cfg_dir}")
    sys.exit(1)

src_cmd = "set -a; " + " ".join(f". {shlex.quote(p)};" for p in files) + " env"
proc = subprocess.run(
    ["/bin/bash", "-lc", src_cmd],
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    universal_newlines=True,
)
env = {}
if proc.returncode == 0:
    for line in proc.stdout.splitlines():
        if "=" not in line:
            continue
        k, v = line.split("=", 1)
        env[k] = v
else:
    msg = proc.stderr.strip() or "failed to source config"
    if json_mode:
        print(json.dumps({
            "schema_version": 1,
            "config_json_contract_version": 1,
            "error": "source_failed",
            "message": msg,
            "cfg_dir": cfg_dir,
            "sources": files,
        }, indent=2, sort_keys=True))
    else:
        print(f"ERROR: {msg}")
        print(c("Hint: fix the config file and rerun 'linux-maint config'", "1;33"))
    sys.exit(1)

values = {k: env.get(k, "") for k in keys}
type_errors = validate_types(values)
if type_errors:
    if json_mode:
        print(json.dumps({
            "schema_version": 1,
            "config_json_contract_version": 1,
            "error": "invalid_types",
            "cfg_dir": cfg_dir,
            "sources": files,
            "errors": type_errors,
        }, indent=2, sort_keys=True))
    else:
        print(header("=== linux-maint config type errors ==="))
        print(f"cfg_dir={cfg_dir}")
        for e in type_errors:
            print(f"- {e.get('key')}: expected {e.get('expected')} got {e.get('value')!r}")
    sys.exit(2)

if json_mode:
    out = {
        "schema_version": 1,
        "config_json_contract_version": 1,
        "cfg_dir": cfg_dir,
        "sources": files,
        "values": values,
    }
    if diff_defaults:
        tpl = find_defaults_template()
        if tpl:
            defaults = parse_defaults([tpl])
            diffs = []
            for k, v in values.items():
                if k in defaults and str(v) != str(defaults[k]):
                    diffs.append({"key": k, "default": defaults[k], "effective": v})
            out["diff_defaults"] = diffs
            out["diff_defaults_template"] = tpl
        else:
            out["diff_defaults"] = []
            out["diff_defaults_error"] = "defaults template not found"
    print(json.dumps(out, indent=2, sort_keys=True))
    sys.exit(0)

print(header("=== linux-maint config (effective) ==="))
print(f"cfg_dir={cfg_dir}")
if show_sources:
    print(c("sources:", "1;36"))
    for p in files:
        print(f"- {p}")
print("")
width = max(len(k) for k in keys)
print(f"{'KEY':<{width}} VALUE")
for k in keys:
    print(f"{k:<{width}} {values.get(k,'')}")

if diff_defaults:
    tpl = find_defaults_template()
    print("")
    print(header("=== config diff vs defaults ==="))
    if not tpl:
        print("defaults template not found")
    else:
        defaults = parse_defaults([tpl])
        diff_rows = []
        for k, v in values.items():
            if k in defaults and str(v) != str(defaults[k]):
                diff_rows.append((k, defaults[k], v))
        if not diff_rows:
            print("no differences (effective matches defaults)")
        else:
            w = max(len(r[0]) for r in diff_rows)
            print(f"{'KEY':<{w}} DEFAULT => EFFECTIVE")
            for k, d, v in diff_rows:
                print(f"{k:<{w}} {d} => {v}")
PY
}

linux_maint_check_status_label() {
  local label="$1" rc="$2" status color
  case "$rc" in
    0) status="OK"; color="$C_GREEN" ;;
    1) status="WARN"; color="$C_YELLOW" ;;
    2) status="CRIT"; color="$C_RED" ;;
    *) status="UNKNOWN"; color="$C_RED" ;;
  esac
  if color_enabled; then
    printf '%s: %s%s%s\n' "$label" "$color" "$status" "$C_RESET"
  else
    printf '%s: %s\n' "$label" "$status"
  fi
}

linux_maint_rc_to_status() {
  local rc="$1"
  case "$rc" in
    0) echo "OK" ;;
    1) echo "WARN" ;;
    2) echo "CRIT" ;;
    *) echo "UNKNOWN" ;;
  esac
}

linux_maint_aggregate_check_rc() {
  local best=0 rc
  for rc in "$@"; do
    case "$rc" in
      0|1|2|3) ;;
      *) rc=3 ;;
    esac
    if [[ "$rc" -gt "$best" ]]; then
      best="$rc"
    fi
  done
  printf '%s\n' "$best"
}

linux_maint_cmd_check() {
    local CHECK_JSON=0
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --json) CHECK_JSON=1; shift 1;;
        -h|--help)
          command_usage check
          exit 0;;
        *) echo "Unknown check flag: $1" >&2; exit 2;;
      esac
    done

    local cv_out cv_rc pf_out pf_rc cfg_dir ok
    set +e
    if [[ "$CHECK_JSON" -eq 1 ]]; then
      # shellcheck disable=SC2154  # Populated by lm_init_runtime_context.
      cv_out="$(bash "$validate" 2>&1)"
      cv_rc=$?
      # shellcheck disable=SC2154  # Populated by lm_init_runtime_context.
      pf_out="$(bash "$preflight" 2>&1)"
      pf_rc=$?
    else
      section "config_validate"
      # shellcheck disable=SC2154  # Populated by lm_init_runtime_context.
      bash "$validate"
      cv_rc=$?
      linux_maint_check_status_label "config_validate" "$cv_rc"
      echo ""
      section "preflight"
      # shellcheck disable=SC2154  # Populated by lm_init_runtime_context.
      bash "$preflight"
      pf_rc=$?
      linux_maint_check_status_label "preflight" "$pf_rc"
      echo ""
    fi
    set -e

    cfg_dir="/etc/linux_maint"
    if [[ "$MODE" == "repo" ]]; then
      cfg_dir="$(linux_maint_effective_cfg_dir)"
    fi
    if [[ "$CHECK_JSON" -eq 1 ]]; then
      ok="false"
      [[ "$cv_rc" -eq 0 && "$pf_rc" -eq 0 ]] && ok="true"
      printf '{'
      printf '"schema_version":1,'
      printf '"check_json_contract_version":1,'
      printf '"config_validate":{"status":"%s","exit_code":%s},' "$(linux_maint_rc_to_status "$cv_rc")" "$cv_rc"
      printf '"preflight":{"status":"%s","exit_code":%s},' "$(linux_maint_rc_to_status "$pf_rc")" "$pf_rc"
      printf '"expected_skips":%s,' "$(expected_skips_json "$cfg_dir")"
      printf '"ok":%s' "$ok"
      printf '}\n'
    else
      expected_skips "$cfg_dir"
    fi
    exit "$(linux_maint_aggregate_check_rc "$cv_rc" "$pf_rc")"
}
