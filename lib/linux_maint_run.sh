#!/usr/bin/env bash
# Run command parsing and preflight helpers for linux-maint.

parse_run_args(){
  DRY_RUN=0
  DEBUG=0
  LIMIT=0
  SHUFFLE=0
  RUN_ONLY=""
  RUN_SKIP=""
  PLAN_ONLY=0
  RUN_JSON=0
  RUN_RESUME=""
  RUN_RESPECT_MAINT=0
  RUN_DRAIN_FILE=""
  RUN_TAGS=""
  RUN_ROLE=""
  RUN_ENV=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --group)
        LM_GROUP="$2"; export LM_GROUP; shift 2;;
      --tag)
        RUN_TAGS="${RUN_TAGS:+$RUN_TAGS,}$2"; shift 2;;
      --role)
        RUN_ROLE="$2"; shift 2;;
      --env)
        RUN_ENV="$2"; shift 2;;
      --hosts)
        tmpf="$(make_list_tmpfile "$2" hosts)"; LM_SERVERLIST="$tmpf"; export LM_SERVERLIST; shift 2;;
      --exclude)
        tmpf="$(make_list_tmpfile "$2" excluded)"; LM_EXCLUDED="$tmpf"; export LM_EXCLUDED; shift 2;;
      --parallel)
        LM_MAX_PARALLEL="$2"; export LM_MAX_PARALLEL; shift 2;;
      --local-only)
        LM_LOCAL_ONLY="true"; export LM_LOCAL_ONLY; shift 1;;
      --ssh-opts)
        LM_SSH_OPTS="$2"; export LM_SSH_OPTS; shift 2;;
      --retry)
        LM_SSH_RETRY="$2"; export LM_SSH_RETRY; shift 2;;
      --host-timeout)
        LM_SSH_TIMEOUT="$2"; export LM_SSH_TIMEOUT; shift 2;;
      --strategy)
        LM_EXEC_STRATEGY="$2"; export LM_EXEC_STRATEGY; shift 2;;
      --quorum-percent)
        LM_EXEC_QUORUM_PERCENT="$2"; export LM_EXEC_QUORUM_PERCENT; shift 2;;
      --respect-maintenance)
        RUN_RESPECT_MAINT=1; shift 1;;
      --drain-file)
        RUN_DRAIN_FILE="$2"; shift 2;;
      --only)
        RUN_ONLY="$2"; shift 2;;
      --skip)
        RUN_SKIP="$2"; shift 2;;
      --plan)
        PLAN_ONLY=1; shift 1;;
      --json)
        RUN_JSON=1; shift 1;;
      --limit)
        LIMIT="$2"; shift 2;;
      --shuffle)
        SHUFFLE=1; shift 1;;
      --progress)
        LM_PROGRESS=1; export LM_PROGRESS; shift 1;;
      --no-progress)
        LM_PROGRESS=0; export LM_PROGRESS; shift 1;;
      --allow-concurrent)
        LM_ALLOW_CONCURRENT=1; export LM_ALLOW_CONCURRENT; shift 1;;
      --lock-timeout)
        LM_RUN_LOCK_TIMEOUT="$2"; export LM_RUN_LOCK_TIMEOUT; shift 2;;
      --debug|--print-env)
        DEBUG=1; shift 1;;
      --dry-run)
        DRY_RUN=1; PLAN_ONLY=1; shift 1;;
      --strict)
        LM_STRICT=1; export LM_STRICT; shift 1;;
      --resume)
        RUN_RESUME="$2"; shift 2;;
      -h|--help)
        command_usage run
        exit 0;;
      *)
        echo "Unknown run flag: $1" >&2
        exit 2;;
    esac
  done
}

linux_maint_cmd_inventory() {
  local subcmd="${1:-}"
  shift || true
  case "$subcmd" in
    lint)
      linux_maint_cmd_inventory_lint "$@"
      ;;
    ""|-h|--help|help)
      command_usage inventory
      exit 0
      ;;
    *)
      echo "ERROR: unknown inventory subcommand: $subcmd" >&2
      command_usage inventory >&2
      exit 2
      ;;
  esac
}

linux_maint_cmd_inventory_lint() {
  local json_out=0 meta_file="" cfg_dir="" servers_file="" hosts_dir=""
  local cfg_dir_explicit=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json) json_out=1; shift ;;
      --meta-file) meta_file="$2"; shift 2 ;;
      --cfg-dir) cfg_dir="$2"; cfg_dir_explicit=1; shift 2 ;;
      -h|--help)
        command_usage inventory
        exit 0
        ;;
      *)
        echo "ERROR: unknown inventory lint flag: $1" >&2
        exit 2
        ;;
    esac
  done

  cfg_dir="${cfg_dir:-$(linux_maint_effective_cfg_dir)}"
  servers_file="${LM_SERVERLIST:-$cfg_dir/servers.txt}"
  hosts_dir="${LM_HOSTS_DIR:-$cfg_dir/hosts.d}"
  if [[ -z "$meta_file" ]]; then
    if [[ "$cfg_dir_explicit" -eq 1 ]]; then
      meta_file="$cfg_dir/inventory_meta.csv"
    else
      meta_file="${LM_INVENTORY_META:-$(linux_maint_effective_inventory_meta_file)}"
    fi
  fi

  if [[ -e "$meta_file" && ! -r "$meta_file" ]]; then
    if [[ "$json_out" -eq 1 ]]; then
      META_FILE="$meta_file" CFG_DIR="$cfg_dir" SERVERS_FILE="$servers_file" HOSTS_DIR="$hosts_dir" python3 - <<'PY'
import json, os
payload = {
    "schema_version": 1,
    "inventory_lint_json_contract_version": 1,
    "meta_file": os.environ["META_FILE"],
    "cfg_dir": os.environ["CFG_DIR"],
    "servers_file": os.environ["SERVERS_FILE"],
    "hosts_dir": os.environ["HOSTS_DIR"],
    "summary": {
        "inventory_hosts": 0,
        "metadata_hosts": 0,
        "duplicate_hosts": 0,
        "missing_metadata_hosts": 0,
        "extra_metadata_hosts": 0,
        "invalid_rows": 0,
        "groups": 0,
        "roles": 0,
        "envs": 0,
        "tags": 0,
    },
    "coverage": {"roles": [], "envs": [], "tags": []},
    "warnings": [],
    "next_steps": ["fix permissions on inventory_meta.csv and rerun inventory lint"],
    "error": "inventory metadata is unreadable",
    "result": "ERROR",
}
print(json.dumps(payload, indent=2, sort_keys=True))
PY
    else
      echo "ERROR: inventory metadata is unreadable: $meta_file" >&2
      echo "Hint: fix permissions on inventory_meta.csv and rerun inventory lint" >&2
    fi
    exit 2
  fi

  local payload
  payload="$(
    META_FILE="$meta_file" CFG_DIR="$cfg_dir" SERVERS_FILE="$servers_file" HOSTS_DIR="$hosts_dir" python3 - <<'PY'
import csv
import json
import os
import re
from collections import Counter
from pathlib import Path

meta_file = Path(os.environ["META_FILE"])
cfg_dir = os.environ["CFG_DIR"]
servers_file = Path(os.environ["SERVERS_FILE"])
hosts_dir = Path(os.environ["HOSTS_DIR"])

expected_columns = ["host", "tags", "role", "env"]
warnings = []
next_steps = []
invalid_rows = []
duplicate_hosts = []
missing_metadata_hosts = []
extra_metadata_hosts = []
roles = Counter()
envs = Counter()
tags = Counter()
inventory_hosts = set()
metadata_hosts = []
metadata_hosts_set = set()
groups = set()

def add_warning(msg):
    if msg not in warnings:
        warnings.append(msg)

def add_next(msg):
    if msg not in next_steps:
        next_steps.append(msg)

def load_hosts_file(path):
    hosts = set()
    if not path.is_file():
        return hosts
    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = raw.split("#", 1)[0].replace(",", " ").strip()
        if not line:
            continue
        for token in line.split():
            if token:
                hosts.add(token)
    return hosts

inventory_hosts.update(load_hosts_file(servers_file))
if hosts_dir.is_dir():
    for group_file in sorted(hosts_dir.glob("*.txt")):
        groups.add(group_file.stem)
        inventory_hosts.update(load_hosts_file(group_file))

header_ok = False
unknown_columns = []
if meta_file.is_file():
    rows = meta_file.read_text(encoding="utf-8", errors="ignore").splitlines()
    active_rows = []
    for raw in rows:
        stripped = raw.strip()
        if not stripped or stripped.startswith("#"):
            continue
        active_rows.append(raw)
    if active_rows:
        try:
            reader = csv.reader(active_rows)
            header = [cell.strip().lower() for cell in next(reader, [])]
        except Exception as exc:
            add_warning(f"inventory_meta.csv is not valid CSV: {exc}")
            add_next("fix CSV syntax in inventory_meta.csv")
            header = []
            reader = []
        if header:
            header_ok = header[:4] == expected_columns and len(header) == 4
            unknown_columns = [col for col in header if col not in expected_columns]
            if not header_ok:
                add_warning("inventory_meta.csv header should be exactly: host,tags,role,env")
                add_next("rewrite the header to host,tags,role,env")
            if unknown_columns:
                add_warning("inventory_meta.csv contains unknown columns: " + ",".join(unknown_columns))
                add_next("remove unknown columns from inventory_meta.csv")
            row_num = 1
            host_counts = Counter()
            for raw_row in reader:
                row_num += 1
                row = [cell.strip() for cell in raw_row]
                if not row or not any(row):
                    continue
                while len(row) < 4:
                    row.append("")
                host, tag_field, role, env = row[:4]
                if not host:
                    invalid_rows.append(f"line {row_num}: empty host")
                    continue
                if host.lower() == "host":
                    invalid_rows.append(f"line {row_num}: duplicate header row")
                    continue
                host_counts[host] += 1
                metadata_hosts.append(host)
                metadata_hosts_set.add(host)
                role_l = role.lower()
                env_l = env.lower()
                if role_l:
                    roles[role_l] += 1
                if env_l:
                    envs[env_l] += 1
                bad_tag_format = False
                normalized = tag_field.replace("|", ";")
                if " " in normalized:
                    bad_tag_format = True
                parts = [part.strip().lower() for part in normalized.split(";")]
                if any(part == "" for part in parts if normalized != ""):
                    bad_tag_format = True
                for part in parts:
                    if not part:
                        continue
                    if not re.match(r"^[A-Za-z0-9._-]+$", part):
                        bad_tag_format = True
                    tags[part] += 1
                if bad_tag_format:
                    invalid_rows.append(f"line {row_num}: invalid tag formatting for host {host}")
                if not role_l:
                    invalid_rows.append(f"line {row_num}: missing role for host {host}")
                if not env_l:
                    invalid_rows.append(f"line {row_num}: missing env for host {host}")
            duplicate_hosts = sorted(host for host, count in host_counts.items() if count > 1)
            if duplicate_hosts:
                add_warning("inventory_meta.csv contains duplicate hosts: " + ",".join(duplicate_hosts))
                add_next("deduplicate hosts in inventory_meta.csv")
    else:
        add_warning("inventory_meta.csv is empty")
        add_next("populate inventory_meta.csv with host,tags,role,env rows or remove it")
else:
    add_warning("inventory_meta.csv is missing")
    add_next("create inventory_meta.csv if you want role/env/tag targeting and coverage reporting")

if invalid_rows:
    add_warning(f"inventory_meta.csv has {len(invalid_rows)} invalid or incomplete rows")
    add_next("fix invalid rows in inventory_meta.csv")

if inventory_hosts:
    missing_metadata_hosts = sorted(inventory_hosts - metadata_hosts_set)
    extra_metadata_hosts = sorted(metadata_hosts_set - inventory_hosts)
    if missing_metadata_hosts:
        add_warning(f"{len(missing_metadata_hosts)} inventory hosts are missing metadata")
        add_next("add metadata rows for missing inventory hosts")
    if extra_metadata_hosts:
        add_warning(f"{len(extra_metadata_hosts)} metadata hosts are not present in servers.txt or hosts.d")
        add_next("remove stale metadata rows or add those hosts back to inventory")
else:
    add_warning("no inventory hosts were found in servers.txt or hosts.d")
    add_next("add hosts to servers.txt or hosts.d before relying on inventory targeting")

result = "OK" if not warnings else "WARN"
payload = {
    "schema_version": 1,
    "inventory_lint_json_contract_version": 1,
    "meta_file": str(meta_file),
    "cfg_dir": cfg_dir,
    "servers_file": str(servers_file),
    "hosts_dir": str(hosts_dir),
    "header_ok": header_ok,
    "unknown_columns": unknown_columns,
    "duplicate_hosts": duplicate_hosts,
    "invalid_rows": invalid_rows,
    "missing_metadata_hosts": missing_metadata_hosts,
    "extra_metadata_hosts": extra_metadata_hosts,
    "summary": {
        "inventory_hosts": len(inventory_hosts),
        "metadata_hosts": len(metadata_hosts_set),
        "duplicate_hosts": len(duplicate_hosts),
        "missing_metadata_hosts": len(missing_metadata_hosts),
        "extra_metadata_hosts": len(extra_metadata_hosts),
        "invalid_rows": len(invalid_rows),
        "groups": len(groups),
        "roles": len(roles),
        "envs": len(envs),
        "tags": len(tags),
    },
    "coverage": {
        "roles": sorted(roles),
        "envs": sorted(envs),
        "tags": sorted(tags),
    },
    "warnings": warnings,
    "next_steps": next_steps,
    "result": result,
}
print(json.dumps(payload, indent=2, sort_keys=True))
PY
  )"

  if [[ "$json_out" -eq 1 ]]; then
    printf '%s\n' "$payload"
  else
    PAYLOAD="$payload" python3 - <<'PY'
import json
import os

payload = json.loads(os.environ["PAYLOAD"])
print("linux-maint inventory lint")
print(f"cfg_dir={payload['cfg_dir']}")
print(f"meta_file={payload['meta_file']}")
print(f"servers_file={payload['servers_file']}")
print(f"hosts_dir={payload['hosts_dir']}")
print("")
print("Coverage:")
summary = payload["summary"]
print(f"- inventory_hosts={summary['inventory_hosts']} metadata_hosts={summary['metadata_hosts']} groups={summary['groups']}")
print(f"- roles={summary['roles']} envs={summary['envs']} tags={summary['tags']}")
if payload["coverage"]["roles"]:
    print(f"- available_roles={','.join(payload['coverage']['roles'])}")
if payload["coverage"]["envs"]:
    print(f"- available_envs={','.join(payload['coverage']['envs'])}")
if payload["coverage"]["tags"]:
    print(f"- available_tags={','.join(payload['coverage']['tags'][:12])}")
if payload["duplicate_hosts"]:
    print("")
    print("Duplicate hosts:")
    for host in payload["duplicate_hosts"]:
        print(f"- {host}")
if payload["missing_metadata_hosts"]:
    print("")
    print("Missing metadata hosts:")
    for host in payload["missing_metadata_hosts"][:12]:
        print(f"- {host}")
if payload["extra_metadata_hosts"]:
    print("")
    print("Extra metadata hosts:")
    for host in payload["extra_metadata_hosts"][:12]:
        print(f"- {host}")
if payload["invalid_rows"]:
    print("")
    print("Row issues:")
    for row in payload["invalid_rows"][:12]:
        print(f"- {row}")
if payload["warnings"]:
    print("")
    print("== Guidance ==")
    for step in payload["next_steps"]:
        print(f"next_step: {step}")
print("")
print("== Summary ==")
print(f"warnings={len(payload['warnings'])}")
print(f"invalid_rows={summary['invalid_rows']}")
print(f"missing_metadata_hosts={summary['missing_metadata_hosts']}")
print(f"duplicate_hosts={summary['duplicate_hosts']}")
print(f"inventory lint {payload['result'].lower()}")
PY
  fi

  case "$(
    PAYLOAD="$payload" python3 - <<'PY'
import json, os
print(json.loads(os.environ["PAYLOAD"]).get("result", "WARN"))
PY
  )" in
    OK) exit 0 ;;
    WARN) exit 1 ;;
    *) exit 2 ;;
  esac
}

resolve_resume_run_id(){
  local target="${1:-}"
  [[ -n "$target" ]] || return 1
  if [[ "$target" != "latest" ]]; then
    printf '%s' "$target"
    return 0
  fi

  local state_dir index_file
  state_dir="$(linux_maint_effective_state_dir)"
  index_file="${LM_RUN_INDEX_FILE:-$state_dir/run_index.jsonl}"
  if [[ ! -f "$index_file" && -z "${LM_RUN_INDEX_FILE:-}" && -z "${LM_STATE_DIR:-}" ]]; then
    for alt in /var/tmp/run_index.jsonl /var/tmp/linux_maint/run_index.jsonl /tmp/linux_maint/run_index.jsonl; do
      if [[ -f "$alt" ]]; then
        index_file="$alt"
        break
      fi
    done
  fi
  [[ -f "$index_file" ]] || return 1
  python3 - "$index_file" <<'PY'
import json, sys
path = sys.argv[1]
run_id = ""
invalid_lines = 0
with open(path, "r", encoding="utf-8", errors="ignore") as f:
    for raw in f:
        raw = raw.strip()
        if not raw:
            continue
        try:
            obj = json.loads(raw)
        except Exception:
            invalid_lines += 1
            continue
        rid = obj.get("run_id")
        if isinstance(rid, str) and rid:
            run_id = rid
if invalid_lines:
    print(
        f"ERROR: run --resume latest requires valid JSON lines in run index: {path} "
        f"(invalid_lines={invalid_lines})",
        file=sys.stderr,
    )
    raise SystemExit(2)
print(run_id)
PY
}

validate_resume_state_file(){
  local run_id="${1:-}"
  local state_dir resume_state_file resume_state_err resume_reason
  [[ -n "$run_id" ]] || return 1
  state_dir="$(linux_maint_effective_state_dir)"
  resume_state_file="${state_dir}/run_state_${run_id}.log"
  if [[ ! -f "$resume_state_file" ]]; then
    echo "ERROR: run --resume requires resume state file: $resume_state_file" >&2
    return 2
  fi
  resume_state_err="$(mktemp -p "${TMPDIR:-/tmp}" linux_maint_resume_state.XXXXXX 2>/dev/null || true)"
  if [[ -z "$resume_state_err" ]]; then
    echo "ERROR: run --resume could not allocate validation temp file" >&2
    return 2
  fi
  if python3 - "$resume_state_file" "$run_id" >/dev/null 2>"$resume_state_err" <<'PY'
import sys

path, expected = sys.argv[1:3]
run_id = None

try:
    fh = open(path, "r", encoding="utf-8", errors="ignore")
except OSError as exc:
    print(f"cannot read resume state: {exc}", file=sys.stderr)
    raise SystemExit(2)

with fh:
    for lineno, raw in enumerate(fh, 1):
        line = raw.strip()
        if not line:
            continue
        if line.startswith("run_id="):
            candidate = line.split("=", 1)[1].strip()
            if not candidate:
                print("empty run_id header", file=sys.stderr)
                raise SystemExit(2)
            if run_id is None:
                run_id = candidate
            elif run_id != candidate:
                print("conflicting run_id headers", file=sys.stderr)
                raise SystemExit(2)
            continue
        if not line.startswith("monitor="):
            continue
        monitor = status = rc = None
        for field in line.split():
            if field.startswith("monitor="):
                monitor = field.split("=", 1)[1]
            elif field.startswith("status="):
                status = field.split("=", 1)[1]
            elif field.startswith("rc="):
                rc = field.split("=", 1)[1]
        if not monitor or status is None or rc is None:
            print(f"invalid monitor line at line {lineno}", file=sys.stderr)
            raise SystemExit(2)

if run_id != expected:
    if run_id is None:
        print("missing run_id header", file=sys.stderr)
    else:
        print(f"run_id header mismatch ({run_id})", file=sys.stderr)
    raise SystemExit(2)
PY
  then
    rm -f "$resume_state_err" 2>/dev/null || true
    return 0
  fi
  resume_reason="$(head -n 1 "$resume_state_err" 2>/dev/null || true)"
  rm -f "$resume_state_err" 2>/dev/null || true
  [[ -n "$resume_reason" ]] || resume_reason="invalid resume state"
  echo "ERROR: run --resume requires valid resume state file: $resume_state_file ($resume_reason)" >&2
  return 2
}

within_maintenance_window(){
  local cfg_dir="$1"
  local mw_file="${LM_MAINTENANCE_FILE:-$cfg_dir/maintenance_windows.conf}"
  [[ -f "$mw_file" ]] || return 0
  python3 - "$mw_file" <<'PY'
import datetime, sys
path = sys.argv[1]
cfg = {}
with open(path, "r", encoding="utf-8", errors="ignore") as f:
    for raw in f:
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        cfg[k.strip().lower()] = v.strip()
enabled = cfg.get("enabled", "0").lower()
if enabled not in ("1", "true", "yes", "on"):
    raise SystemExit(0)
window = cfg.get("window", "")
if not window or "-" not in window:
    raise SystemExit(0)
start_s, end_s = [p.strip() for p in window.split("-", 1)]
def parse_hhmm(s):
    h, m = s.split(":", 1)
    return int(h), int(m)
try:
    sh, sm = parse_hhmm(start_s)
    eh, em = parse_hhmm(end_s)
except Exception:
    raise SystemExit(0)
now = datetime.datetime.now()
cur = now.hour * 60 + now.minute
start = sh * 60 + sm
end = eh * 60 + em
days = cfg.get("days", "").strip()
if days:
    valid = set()
    for d in days.split(","):
        d = d.strip().lower()
        if d:
            valid.add(d[:3])
    if valid and now.strftime("%a").lower()[:3] not in valid:
        raise SystemExit(2)
inside = (start <= cur <= end) if start <= end else (cur >= start or cur <= end)
raise SystemExit(0 if inside else 2)
PY
}

resolve_run_monitors_text(){
  local local_monitors=""
  if [[ -n "${LM_MONITORS:-}" ]]; then
    read -r -a _lm_list <<< "${LM_MONITORS}"
    local_monitors="$(printf '%s\n' "${_lm_list[@]}")"
  else
    local_monitors="$(get_default_monitors 2>/dev/null || true)"
    if [[ -z "$local_monitors" ]]; then
      local_monitors="$(available_monitors 2>/dev/null || true)"
    fi
  fi
  printf '%s\n' "$local_monitors" | sed '/^$/d'
}

enforce_monitor_privilege_policy(){
  local monitors_text="$1"
  local cfg_dir="$2"
  local policy_file="${LM_MONITOR_PRIV_POLICY_FILE:-$cfg_dir/monitor_privilege_policy.conf}"
  [[ -f "$policy_file" ]] || return 0
  MONITORS_TEXT="$monitors_text" POLICY_FILE="$policy_file" python3 - <<'PY'
import json, os, re, sys

policy_file = os.environ.get("POLICY_FILE", "")
monitors = [m.strip() for m in os.environ.get("MONITORS_TEXT", "").splitlines() if m.strip()]

policy = {}
errors = []
allowed = {"requires_root", "allow_sudo", "no_sudo"}
try:
    with open(policy_file, "r", encoding="utf-8", errors="ignore") as f:
        for ln, raw in enumerate(f, start=1):
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            if "=" not in line:
                errors.append(f"{policy_file}:{ln}: missing '='")
                continue
            k, v = line.split("=", 1)
            key = k.strip()
            key = key[:-3] if key.endswith(".sh") else key
            mode = v.strip()
            if mode not in allowed:
                errors.append(f"{policy_file}:{ln}: invalid mode '{mode}' for monitor '{key}'")
                continue
            policy[key] = mode
except FileNotFoundError:
    raise SystemExit(0)

if errors:
    for e in errors:
        print(f"ERROR: {e}", file=sys.stderr)
    raise SystemExit(2)

is_root = (os.geteuid() == 0)
violations = []
for m in monitors:
    key = m[:-3] if m.endswith(".sh") else m
    mode = policy.get(key)
    if not mode:
        continue
    if mode == "requires_root" and not is_root:
        violations.append(f"{key}: requires_root but current user is non-root")
    elif mode == "no_sudo" and is_root:
        violations.append(f"{key}: no_sudo but current user is root")

if violations:
    print(f"ERROR: monitor privilege policy violations ({policy_file}):", file=sys.stderr)
    for v in violations:
        print(f"- {v}", file=sys.stderr)
    raise SystemExit(2)
PY
}

resolve_run_cfg_dir(){
  linux_maint_effective_cfg_dir
}

run_apply_mode_defaults(){
  if [[ "$MODE" == "repo" ]]; then
    local repo_cfg_dir
    repo_cfg_dir="$(linux_maint_effective_cfg_dir)"
    export LM_CFG_DIR="${LM_CFG_DIR:-$repo_cfg_dir}"
    export LM_SERVERLIST="${LM_SERVERLIST:-$repo_cfg_dir/servers.txt}"
    export LM_EXCLUDED="${LM_EXCLUDED:-$repo_cfg_dir/excluded.txt}"
    export LM_HOSTS_DIR="${LM_HOSTS_DIR:-$repo_cfg_dir/hosts.d}"
  fi
  export LM_INVENTORY_META="${LM_INVENTORY_META:-$(linux_maint_effective_inventory_meta_file)}"
  if [[ -n "${RUN_TAGS:-}" ]]; then
    export LM_FILTER_TAGS="$RUN_TAGS"
  fi
  if [[ -n "${RUN_ROLE:-}" ]]; then
    export LM_FILTER_ROLE="$RUN_ROLE"
  fi
  if [[ -n "${RUN_ENV:-}" ]]; then
    export LM_FILTER_ENV="$RUN_ENV"
  fi
}

run_validate_execution_args(){
  if [[ -n "${LM_SSH_RETRY:-}" ]] && [[ ! "${LM_SSH_RETRY}" =~ ^[0-9]+$ ]]; then
    echo "ERROR: --retry must be a non-negative integer" >&2
    exit 2
  fi
  if [[ -n "${LM_SSH_TIMEOUT:-}" ]] && [[ ! "${LM_SSH_TIMEOUT}" =~ ^[0-9]+$ ]]; then
    echo "ERROR: --host-timeout must be a non-negative integer" >&2
    exit 2
  fi
  if [[ -n "${RUN_TAGS:-}" && ! "${RUN_TAGS}" =~ [A-Za-z0-9._-] ]]; then
    echo "ERROR: --tag requires at least one non-empty tag token" >&2
    exit 2
  fi
  if [[ -n "${RUN_ROLE:-}" && ! "${RUN_ROLE}" =~ [A-Za-z0-9._-] ]]; then
    echo "ERROR: --role requires a non-empty value" >&2
    exit 2
  fi
  if [[ -n "${RUN_ENV:-}" && ! "${RUN_ENV}" =~ [A-Za-z0-9._-] ]]; then
    echo "ERROR: --env requires a non-empty value" >&2
    exit 2
  fi
  case "${LM_EXEC_STRATEGY:-fail-soft}" in
    fail-soft|fail-fast|quorum) ;;
    *)
      echo "ERROR: --strategy must be one of fail-soft|fail-fast|quorum" >&2
      exit 2
      ;;
  esac
  if [[ "${LM_EXEC_STRATEGY:-fail-soft}" == "quorum" ]]; then
    if [[ ! "${LM_EXEC_QUORUM_PERCENT:-80}" =~ ^[0-9]+$ ]] || (( LM_EXEC_QUORUM_PERCENT < 1 || LM_EXEC_QUORUM_PERCENT > 100 )); then
      echo "ERROR: --quorum-percent must be an integer in range 1..100" >&2
      exit 2
    fi
  fi
}

run_prepare_host_selection(){
  local meta_file host_count host
  declare -ga RUN_RESOLVED_HOSTS_ARRAY=()

  meta_file="${LM_INVENTORY_META:-$(linux_maint_effective_inventory_meta_file)}"
  if [[ -n "${RUN_TAGS:-}${RUN_ROLE:-}${RUN_ENV:-}" ]]; then
    if [[ ! -f "$meta_file" ]]; then
      echo "ERROR: inventory filters require inventory metadata: $meta_file" >&2
      echo "Hint: create inventory_meta.csv with host,tags,role,env or run without --tag/--role/--env" >&2
      exit 2
    fi
    if [[ ! -r "$meta_file" ]]; then
      echo "ERROR: inventory metadata is unreadable: $meta_file" >&2
      echo "Hint: fix permissions on inventory_meta.csv or run without --tag/--role/--env" >&2
      exit 2
    fi
  fi

  mapfile -t RUN_RESOLVED_HOSTS_ARRAY < <(resolve_run_hosts)
  if [[ "${#RUN_RESOLVED_HOSTS_ARRAY[@]}" -gt 0 ]]; then
    local -a _filtered_hosts=()
    for host in "${RUN_RESOLVED_HOSTS_ARRAY[@]}"; do
      [[ -n "$host" ]] && _filtered_hosts+=("$host")
    done
    RUN_RESOLVED_HOSTS_ARRAY=("${_filtered_hosts[@]}")
  fi
  host_count="${#RUN_RESOLVED_HOSTS_ARRAY[@]}"
  RUN_HOST_COUNT="$host_count"
  export RUN_HOST_COUNT

  RUN_INVENTORY_CONTEXT_JSON="$(
    python3 - "$meta_file" "${RUN_TAGS:-}" "${RUN_ROLE:-}" "${RUN_ENV:-}" "${RUN_RESOLVED_HOSTS_ARRAY[@]}" <<'PY'
import json, os, sys
from collections import Counter

meta_file, tag_filter, role_filter, env_filter, *hosts = sys.argv[1:]
ctx = {
    "meta_file": meta_file,
    "meta_present": os.path.isfile(meta_file),
    "meta_readable": os.access(meta_file, os.R_OK) if os.path.exists(meta_file) else False,
    "filters": {
        "tag": tag_filter or None,
        "role": role_filter or None,
        "env": env_filter or None,
    },
    "resolved_hosts": hosts,
    "resolved_host_count": len(hosts),
    "inventory_host_count": 0,
    "inventory_match_count": 0,
    "available_roles": [],
    "available_envs": [],
    "available_tags": [],
}
if ctx["meta_present"] and ctx["meta_readable"]:
    role_counts = Counter()
    env_counts = Counter()
    tag_counts = Counter()
    meta_hosts = set()
    matched = set()
    with open(meta_file, "r", encoding="utf-8", errors="ignore") as fh:
        for raw in fh:
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            parts = [p.strip() for p in line.split(",")]
            if not parts:
                continue
            host = parts[0]
            if not host or host == "host":
                continue
            tags = (parts[1] if len(parts) > 1 else "").replace("|", ";")
            role = (parts[2] if len(parts) > 2 else "").lower()
            env = (parts[3] if len(parts) > 3 else "").lower()
            meta_hosts.add(host)
            if role:
                role_counts[role] += 1
            if env:
                env_counts[env] += 1
            for tag in [t.strip().lower() for t in tags.replace(" ", ";").split(";") if t.strip()]:
                tag_counts[tag] += 1
            if host in hosts:
                matched.add(host)
    ctx["inventory_host_count"] = len(meta_hosts)
    ctx["inventory_match_count"] = len(matched)
    ctx["available_roles"] = sorted(role_counts)
    ctx["available_envs"] = sorted(env_counts)
    ctx["available_tags"] = sorted(tag_counts)
print(json.dumps(ctx, sort_keys=True))
PY
  )"
  export RUN_INVENTORY_CONTEXT_JSON

  if (( host_count == 0 )); then
    if [[ -n "${RUN_TAGS:-}${RUN_ROLE:-}${RUN_ENV:-}" ]]; then
      local empty_hint
      empty_hint="$(python3 - <<'PY'
import json, os
ctx = json.loads(os.environ.get("RUN_INVENTORY_CONTEXT_JSON", "{}"))
filters = ctx.get("filters", {})
parts = []
for key in ("tag", "role", "env"):
    value = filters.get(key)
    if value:
        parts.append(f"{key}={value}")
available = []
for label, key in (("roles", "available_roles"), ("envs", "available_envs"), ("tags", "available_tags")):
    values = ctx.get(key) or []
    if values:
        available.append(f"{label}={','.join(values[:8])}")
out = []
if parts:
    out.append("requested: " + " ".join(parts))
if available:
    out.append("available: " + " ".join(available))
print("\n".join(out))
PY
)"
      echo "ERROR: inventory filters matched 0 hosts using $meta_file" >&2
      [[ -n "$empty_hint" ]] && printf '%s\n' "$empty_hint" >&2
      echo "Hint: run linux-maint run --plan without filters to inspect the base inventory" >&2
      exit 2
    fi
    echo "ERROR: no hosts resolved for run" >&2
    exit 2
  fi
}

run_prepare_resume_state(){
  local resume_id resume_rc
  if [[ -n "${RUN_RESUME:-}" ]]; then
    set +e
    resume_id="$(resolve_resume_run_id "$RUN_RESUME")"
    resume_rc=$?
    set -e
    if [[ "$resume_rc" -eq 2 ]]; then
      exit 2
    fi
    if [[ -z "${resume_id:-}" ]]; then
      echo "ERROR: unable to resolve --resume target '$RUN_RESUME'" >&2
      echo "Hint: pass an explicit run_id from linux-maint history --json" >&2
      exit 2
    fi
    if ! validate_resume_state_file "$resume_id"; then
      exit 2
    fi
    export LM_RESUME_RUN_ID="$resume_id"
    export LM_RUN_ID="$resume_id"
  fi
  if [[ -n "${RUN_DRAIN_FILE:-}" ]]; then
    export LM_DRAIN_MODE=1
    export LM_DRAIN_FILE="$RUN_DRAIN_FILE"
  fi
}

prepare_run_monitor_selection(){
  local cfg_dir="$1"
  local local_monitors

  if [[ -n "${RUN_ONLY:-}" ]]; then
    validate_monitor_list "$(normalize_monitor_list "$RUN_ONLY")" || exit $?
  fi
  if [[ -n "${RUN_SKIP:-}" ]]; then
    validate_monitor_list "$(normalize_monitor_list "$RUN_SKIP")" || exit $?
  fi

  if [[ -n "${RUN_ONLY:-}" || -n "${RUN_SKIP:-}" ]]; then
    mapfile -t _monitors < <(filter_monitors_only_skip "${RUN_ONLY:-}" "${RUN_SKIP:-}")
    if [[ "${#_monitors[@]}" -eq 0 ]]; then
      echo "ERROR: monitor filter produced empty list" >&2
      exit 2
    fi
    export LM_MONITORS="${_monitors[*]}"
  fi
  if [[ -n "${LM_MONITORS:-}" ]]; then
    read -r -a _lm_list <<< "${LM_MONITORS}"
    validate_monitor_list "$(printf '%s\n' "${_lm_list[@]}")" || exit $?
  fi

  local_monitors="$(resolve_run_monitors_text)"
  if [[ -z "$local_monitors" ]]; then
    echo "ERROR: no monitors resolved for run" >&2
    exit 2
  fi
  enforce_monitor_privilege_policy "$local_monitors" "$cfg_dir"
  RUN_LOCAL_MONITORS="$local_monitors"
  export RUN_LOCAL_MONITORS
}

run_debug_dump(){
  local wrapper="$1"
  [[ "${DEBUG:-0}" -eq 1 ]] || return 0
  echo "=== linux-maint run debug ==="
  echo "MODE=${MODE}"
  echo "wrapper=${wrapper}"
  echo "LM_GROUP=${LM_GROUP:-}"
  echo "LM_HOSTS_DIR=${LM_HOSTS_DIR:-}"
  echo "LM_SERVERLIST=${LM_SERVERLIST:-}"
  echo "LM_EXCLUDED=${LM_EXCLUDED:-}"
  echo "LM_MAX_PARALLEL=${LM_MAX_PARALLEL:-}"
  echo "LM_INVENTORY_META=${LM_INVENTORY_META:-}"
  echo "RUN_TAGS=${RUN_TAGS:-}"
  echo "RUN_ROLE=${RUN_ROLE:-}"
  echo "RUN_ENV=${RUN_ENV:-}"
  echo "LM_LOCAL_ONLY=${LM_LOCAL_ONLY:-}"
  echo "LM_MONITORS=${LM_MONITORS:-}"
  echo "LM_SSH_OPTS=${LM_SSH_OPTS:-}"
  echo "LM_SSH_RETRY=${LM_SSH_RETRY:-}"
  echo "LM_SSH_TIMEOUT=${LM_SSH_TIMEOUT:-}"
  echo "LM_EXEC_STRATEGY=${LM_EXEC_STRATEGY:-}"
  echo "LM_EXEC_QUORUM_PERCENT=${LM_EXEC_QUORUM_PERCENT:-}"
  echo "LM_DRAIN_FILE=${LM_DRAIN_FILE:-}"
  echo "LIMIT=${LIMIT:-0}"
  echo "SHUFFLE=${SHUFFLE:-0}"
  echo "PLAN_ONLY=${PLAN_ONLY:-0}"
  echo "DRY_RUN=${DRY_RUN:-0}"
  echo "RUN_JSON=${RUN_JSON:-0}"
  echo "RUN_RESUME=${RUN_RESUME:-}"
  echo "RUN_RESPECT_MAINT=${RUN_RESPECT_MAINT:-0}"
  echo "LM_RESUME_RUN_ID=${LM_RESUME_RUN_ID:-}"
  echo "============================="
}

emit_run_plan(){
  local local_monitors="$1"
  local gf first h m inventory_meta_present inventory_host_count inventory_match_count
  local available_roles available_envs available_tags
  local -a _hosts=() _inventory_lines=() _roles=() _envs=() _tags=()

  if [[ -n "${LM_GROUP:-}" ]]; then
    gf="${LM_HOSTS_DIR:-/etc/linux_maint/hosts.d}/${LM_GROUP}.txt"
    [[ -f "$gf" ]] || echo "NOTE: LM_GROUP=$LM_GROUP but group file not found: $gf (will fall back)" >&2
  fi

  if [[ "${#RUN_RESOLVED_HOSTS_ARRAY[@]}" -gt 0 ]]; then
    _hosts=("${RUN_RESOLVED_HOSTS_ARRAY[@]}")
  else
    mapfile -t _hosts < <(resolve_run_hosts)
  fi
  if [[ -n "${RUN_INVENTORY_CONTEXT_JSON:-}" ]]; then
    mapfile -t _inventory_lines < <(
      RUN_INVENTORY_CONTEXT_JSON="$RUN_INVENTORY_CONTEXT_JSON" python3 - <<'PY'
import json, os
ctx = json.loads(os.environ.get("RUN_INVENTORY_CONTEXT_JSON", "{}"))
print(f"meta_present={1 if ctx.get('meta_present') else 0}")
print(f"inventory_host_count={ctx.get('inventory_host_count', 0)}")
print(f"inventory_match_count={ctx.get('inventory_match_count', 0)}")
print(f"available_roles={','.join(ctx.get('available_roles') or [])}")
print(f"available_envs={','.join(ctx.get('available_envs') or [])}")
print(f"available_tags={','.join((ctx.get('available_tags') or [])[:8])}")
PY
    )
    local item key value
    for item in "${_inventory_lines[@]}"; do
      key="${item%%=*}"
      value="${item#*=}"
      case "$key" in
        meta_present) inventory_meta_present="$value" ;;
        inventory_host_count) inventory_host_count="$value" ;;
        inventory_match_count) inventory_match_count="$value" ;;
        available_roles) available_roles="$value" ;;
        available_envs) available_envs="$value" ;;
        available_tags) available_tags="$value" ;;
      esac
    done
  fi

  if [[ "${RUN_JSON:-0}" -eq 1 ]]; then
    printf '{'
    printf '"mode":"%s",' "$MODE"
    if [[ "${LM_LOCAL_ONLY:-false}" == "true" ]]; then
      printf '"local_only":true,'
    else
      printf '"local_only":false,'
    fi
    printf '"parallel":%s,' "${LM_MAX_PARALLEL:-0}"
    printf '"retry":%s,' "${LM_SSH_RETRY:-0}"
    printf '"host_timeout":%s,' "${LM_SSH_TIMEOUT:-0}"
    printf '"strategy":"%s",' "$(json_escape "${LM_EXEC_STRATEGY:-fail-soft}")"
    printf '"quorum_percent":%s,' "${LM_EXEC_QUORUM_PERCENT:-80}"
    if [[ -n "${LM_GROUP:-}" ]]; then
      printf '"group":"%s",' "$(json_escape "$LM_GROUP")"
    else
      printf '"group":null,'
    fi
    if [[ -n "${RUN_TAGS:-}" ]]; then
      printf '"tag_filter":"%s",' "$(json_escape "$RUN_TAGS")"
    else
      printf '"tag_filter":null,'
    fi
    if [[ -n "${RUN_ROLE:-}" ]]; then
      printf '"role_filter":"%s",' "$(json_escape "$RUN_ROLE")"
    else
      printf '"role_filter":null,'
    fi
    if [[ -n "${RUN_ENV:-}" ]]; then
      printf '"env_filter":"%s",' "$(json_escape "$RUN_ENV")"
    else
      printf '"env_filter":null,'
    fi
    printf '"inventory_meta":"%s",' "$(json_escape "${LM_INVENTORY_META:-$(linux_maint_effective_inventory_meta_file)}")"
    printf '"inventory_meta_present":%s,' "$([[ "${inventory_meta_present:-0}" == "1" ]] && echo true || echo false)"
    printf '"inventory_host_count":%s,' "${inventory_host_count:-0}"
    printf '"inventory_match_count":%s,' "${inventory_match_count:-0}"
    printf '"resolved_host_count":%s,' "${#_hosts[@]}"
    printf '"limit":%s,' "${LIMIT:-0}"
    printf '"shuffle":%s,' "$([[ "${SHUFFLE:-0}" -eq 1 ]] && echo true || echo false)"
    printf '"available_roles":['
    first=1
    IFS=',' read -r -a _roles <<< "${available_roles:-}"
    for h in "${_roles[@]}"; do
      [[ -z "$h" ]] && continue
      [[ "$first" -eq 0 ]] && printf ','
      first=0
      printf '"%s"' "$(json_escape "$h")"
    done
    printf '],'
    printf '"available_envs":['
    first=1
    IFS=',' read -r -a _envs <<< "${available_envs:-}"
    for h in "${_envs[@]}"; do
      [[ -z "$h" ]] && continue
      [[ "$first" -eq 0 ]] && printf ','
      first=0
      printf '"%s"' "$(json_escape "$h")"
    done
    printf '],'
    printf '"available_tags":['
    first=1
    IFS=',' read -r -a _tags <<< "${available_tags:-}"
    for h in "${_tags[@]}"; do
      [[ -z "$h" ]] && continue
      [[ "$first" -eq 0 ]] && printf ','
      first=0
      printf '"%s"' "$(json_escape "$h")"
    done
    printf '],'
    printf '"hosts":['
    first=1
    for h in "${_hosts[@]}"; do
      [[ "$first" -eq 0 ]] && printf ','
      first=0
      printf '"%s"' "$(json_escape "$h")"
    done
    printf '],"monitors":['
    first=1
    while IFS= read -r m; do
      [[ -z "$m" ]] && continue
      [[ "$first" -eq 0 ]] && printf ','
      first=0
      printf '"%s"' "$(json_escape "$m")"
    done <<< "$local_monitors"
    printf ']}\n'
    exit 0
  fi

  if [[ -t 1 ]]; then
    section "run plan"
    echo "mode=${MODE} local_only=${LM_LOCAL_ONLY:-false} parallel=${LM_MAX_PARALLEL:-0}"
    [[ -n "${LM_GROUP:-}" ]] && echo "group=${LM_GROUP}"
    [[ -n "${RUN_TAGS:-}" ]] && echo "tag_filter=${RUN_TAGS}"
    [[ -n "${RUN_ROLE:-}" ]] && echo "role_filter=${RUN_ROLE}"
    [[ -n "${RUN_ENV:-}" ]] && echo "env_filter=${RUN_ENV}"
    if [[ -n "${RUN_TAGS:-}${RUN_ROLE:-}${RUN_ENV:-}" || "${inventory_meta_present:-0}" == "1" ]]; then
      echo "inventory_meta=${LM_INVENTORY_META:-$(linux_maint_effective_inventory_meta_file)}"
      echo "inventory_hosts=${inventory_host_count:-0} matched_hosts=${inventory_match_count:-0} resolved_hosts=${#_hosts[@]}"
      [[ -n "${available_roles:-}" ]] && echo "available_roles=${available_roles}"
      [[ -n "${available_envs:-}" ]] && echo "available_envs=${available_envs}"
      [[ -n "${available_tags:-}" ]] && echo "available_tags=${available_tags}"
    fi
    echo ""
  fi
  echo "Resolved hosts (${#_hosts[@]}):"
  printf '%s\n' "${_hosts[@]}"
  if [[ -t 1 ]]; then
    echo ""
    echo "Monitors ($(printf '%s\n' "$local_monitors" | sed '/^$/d' | wc -l | tr -d ' ')):"
  fi
  if [[ -n "$local_monitors" ]]; then
    printf '%s\n' "$local_monitors"
  fi
  exit 0
}

run_enforce_maintenance_window(){
  local cfg_dir="$1"
  if [[ "${RUN_RESPECT_MAINT:-0}" -eq 1 ]]; then
    if ! within_maintenance_window "$cfg_dir"; then
      echo "Run skipped: outside configured maintenance window ($cfg_dir/maintenance_windows.conf)"
      exit 0
    fi
  fi
}

run_execute_wrapper(){
  local wrapper="$1"
  local rc

  audit_log_append "run" "start" "wrapper=$wrapper local_only=${LM_LOCAL_ONLY:-false} group=${LM_GROUP:-} strategy=${LM_EXEC_STRATEGY:-fail-soft}"
  set +e
  if [[ "$wrapper" == "$SBIN"/* ]]; then
    "$wrapper"
  else
    bash "$wrapper"
  fi
  rc=$?
  set -e
  audit_log_append "run" "$([[ "$rc" -eq 0 ]] && echo success || echo failure)" "rc=$rc wrapper=$wrapper"
  if [[ -t 1 ]]; then
    echo ""
    echo "Run complete (exit_code=$rc)"
    echo "Summary: $(linux_maint_reporting_summary_latest)"
    echo "Log: $(linux_maint_reporting_latest_log)"
    echo "Next: linux-maint report"
    echo "Tip: linux-maint status --reasons 5"
    echo "If WARN/CRIT: linux-maint doctor"
  fi
  RUN_EXEC_RC="$rc"
}
