#!/usr/bin/env bash
# Notify/ticket/audit/cm-hook helpers for linux-maint.

linux_maint_cmd_notify() {
  local NP_PROVIDER="" NP_URL="" NP_TO="" NP_ROUTING_KEY=""
  local NP_SEVERITY="warning" NP_SOURCE="linux-maint"
  local NP_SUBJECT="linux-maint notification" NP_MESSAGE="linux-maint test notification"
  local NP_DRY_RUN=0
  local NP_CONNECT_TIMEOUT="${LM_NOTIFY_CONNECT_TIMEOUT:-5}"
  local NP_MAX_TIME="${LM_NOTIFY_MAX_TIME:-15}"
  local payload=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --provider) NP_PROVIDER="$2"; shift 2;;
      --url) NP_URL="$2"; shift 2;;
      --to) NP_TO="$2"; shift 2;;
      --routing-key) NP_ROUTING_KEY="$2"; shift 2;;
      --severity) NP_SEVERITY="$2"; shift 2;;
      --source) NP_SOURCE="$2"; shift 2;;
      --subject) NP_SUBJECT="$2"; shift 2;;
      --message) NP_MESSAGE="$2"; shift 2;;
      --dry-run) NP_DRY_RUN=1; shift 1;;
      -h|--help) command_usage notify; exit 0;;
      *) echo "Unknown notify flag: $1" >&2; exit 2;;
    esac
  done

  [[ "$NP_CONNECT_TIMEOUT" =~ ^[0-9]+([.][0-9]+)?$ ]] || { echo "ERROR: LM_NOTIFY_CONNECT_TIMEOUT must be numeric" >&2; exit 2; }
  [[ "$NP_MAX_TIME" =~ ^[0-9]+([.][0-9]+)?$ ]] || { echo "ERROR: LM_NOTIFY_MAX_TIME must be numeric" >&2; exit 2; }

  case "$NP_PROVIDER" in
    webhook|slack|teams|email|pagerduty) ;;
    *)
      echo "ERROR: --provider must be one of webhook|slack|teams|email|pagerduty" >&2
      exit 2
      ;;
  esac

  if [[ "$NP_PROVIDER" == "email" ]]; then
    [[ -n "$NP_TO" ]] || { echo "ERROR: --to is required for provider=email" >&2; exit 2; }
    if [[ "$NP_DRY_RUN" -eq 1 ]]; then
      echo "DRY_RUN provider=email to=$NP_TO subject=$NP_SUBJECT message=$NP_MESSAGE"
      exit 0
    fi
    if ! command -v mail >/dev/null 2>&1; then
      echo "ERROR: mail command not found" >&2
      exit 2
    fi
    printf '%s\n' "$NP_MESSAGE" | mail -s "$NP_SUBJECT" "$NP_TO"
    echo "notification sent via email"
    exit 0
  fi

  if [[ "$NP_PROVIDER" == "pagerduty" ]]; then
    [[ -n "$NP_ROUTING_KEY" ]] || { echo "ERROR: --routing-key is required for provider=pagerduty" >&2; exit 2; }
    case "$NP_SEVERITY" in
      critical|error|warning|info) ;;
      *) echo "ERROR: --severity must be one of critical|error|warning|info" >&2; exit 2;;
    esac
    NP_URL="${NP_URL:-https://events.pagerduty.com/v2/enqueue}"
    payload="$(python3 - "$NP_ROUTING_KEY" "$NP_MESSAGE" "$NP_SOURCE" "$NP_SEVERITY" <<'PY'
import json, sys
routing_key, summary, source, severity = sys.argv[1:5]
print(json.dumps({
  "routing_key": routing_key,
  "event_action": "trigger",
  "payload": {
    "summary": summary,
    "source": source,
    "severity": severity
  }
}))
PY
)"
    if [[ "$NP_DRY_RUN" -eq 1 ]]; then
      echo "DRY_RUN provider=$NP_PROVIDER url=$NP_URL payload=$payload"
      exit 0
    fi
    if ! command -v curl >/dev/null 2>&1; then
      echo "ERROR: curl command not found" >&2
      exit 2
    fi
    curl -fsS --connect-timeout "$NP_CONNECT_TIMEOUT" --max-time "$NP_MAX_TIME" -X POST -H 'Content-Type: application/json' --data "$payload" "$NP_URL" >/dev/null
    echo "notification sent via $NP_PROVIDER"
    exit 0
  fi

  [[ -n "$NP_URL" ]] || { echo "ERROR: --url is required for provider=$NP_PROVIDER" >&2; exit 2; }
  payload="$(python3 - "$NP_MESSAGE" <<'PY'
import json, sys
msg = sys.argv[1]
print(json.dumps({"text": msg}))
PY
)"
  if [[ "$NP_DRY_RUN" -eq 1 ]]; then
    echo "DRY_RUN provider=$NP_PROVIDER url=$NP_URL payload=$payload"
    exit 0
  fi
  if ! command -v curl >/dev/null 2>&1; then
    echo "ERROR: curl command not found" >&2
    exit 2
  fi
  curl -fsS --connect-timeout "$NP_CONNECT_TIMEOUT" --max-time "$NP_MAX_TIME" -X POST -H 'Content-Type: application/json' --data "$payload" "$NP_URL" >/dev/null
  echo "notification sent via $NP_PROVIDER"
}

linux_maint_cmd_ticket() {
  local TK_PROVIDER="" TK_URL="" TK_TITLE="" TK_BODY=""
  local TK_PROJECT="OPS" TK_ISSUE_TYPE="Task" TK_JSON=0 TK_DRY_RUN=0
  local TK_CONNECT_TIMEOUT="${LM_TICKET_CONNECT_TIMEOUT:-5}"
  local TK_MAX_TIME="${LM_TICKET_MAX_TIME:-15}"
  local payload=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --provider) TK_PROVIDER="$2"; shift 2;;
      --url) TK_URL="$2"; shift 2;;
      --title) TK_TITLE="$2"; shift 2;;
      --body) TK_BODY="$2"; shift 2;;
      --project) TK_PROJECT="$2"; shift 2;;
      --issue-type) TK_ISSUE_TYPE="$2"; shift 2;;
      --json) TK_JSON=1; shift 1;;
      --dry-run) TK_DRY_RUN=1; shift 1;;
      -h|--help) command_usage ticket; exit 0;;
      *) echo "Unknown ticket flag: $1" >&2; exit 2;;
    esac
  done

  [[ "$TK_CONNECT_TIMEOUT" =~ ^[0-9]+([.][0-9]+)?$ ]] || { echo "ERROR: LM_TICKET_CONNECT_TIMEOUT must be numeric" >&2; exit 2; }
  [[ "$TK_MAX_TIME" =~ ^[0-9]+([.][0-9]+)?$ ]] || { echo "ERROR: LM_TICKET_MAX_TIME must be numeric" >&2; exit 2; }

  case "$TK_PROVIDER" in
    jira|servicenow) ;;
    *) echo "ERROR: --provider must be jira|servicenow" >&2; exit 2;;
  esac
  [[ -n "$TK_URL" ]] || { echo "ERROR: --url is required" >&2; exit 2; }
  [[ -n "$TK_TITLE" ]] || { echo "ERROR: --title is required" >&2; exit 2; }
  [[ -n "$TK_BODY" ]] || { echo "ERROR: --body is required" >&2; exit 2; }

  if [[ "$TK_PROVIDER" == "jira" ]]; then
    payload="$(python3 - "$TK_PROJECT" "$TK_ISSUE_TYPE" "$TK_TITLE" "$TK_BODY" <<'PY'
import json, sys
project, issue_type, title, body = sys.argv[1:5]
print(json.dumps({
  "fields": {
    "project": {"key": project},
    "summary": title,
    "description": body,
    "issuetype": {"name": issue_type}
  }
}))
PY
)"
  else
    payload="$(python3 - "$TK_TITLE" "$TK_BODY" <<'PY'
import json, sys
title, body = sys.argv[1:3]
print(json.dumps({
  "short_description": title,
  "description": body
}))
PY
)"
  fi

  if [[ "$TK_DRY_RUN" -eq 1 ]]; then
    if [[ "$TK_JSON" -eq 1 ]]; then
      python3 - "$TK_PROVIDER" "$TK_URL" "$payload" <<'PY'
import json, sys
provider, url, payload_raw = sys.argv[1:4]
payload = json.loads(payload_raw)
print(json.dumps({
  "ticket_contract_version": 1,
  "provider": provider,
  "url": url,
  "dry_run": True,
  "submitted": False,
  "payload": payload
}, indent=2, sort_keys=True))
PY
      exit 0
    fi
    echo "DRY_RUN provider=$TK_PROVIDER url=$TK_URL payload=$payload"
    exit 0
  fi

  if ! command -v curl >/dev/null 2>&1; then
    echo "ERROR: curl command not found" >&2
    exit 2
  fi
  curl -fsS --connect-timeout "$TK_CONNECT_TIMEOUT" --max-time "$TK_MAX_TIME" -X POST -H 'Content-Type: application/json' --data "$payload" "$TK_URL" >/dev/null
  if [[ "$TK_JSON" -eq 1 ]]; then
    python3 - "$TK_PROVIDER" "$TK_URL" <<'PY'
import json, sys
provider, url = sys.argv[1:3]
print(json.dumps({
  "ticket_contract_version": 1,
  "provider": provider,
  "url": url,
  "dry_run": False,
  "submitted": True
}, indent=2, sort_keys=True))
PY
    exit 0
  fi
  echo "ticket submitted via $TK_PROVIDER"
}

linux_maint_cmd_audit_log() {
  local AL_LAST=50 AL_JSON=0 AL_VERIFY=0
  local AL_FILE=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --last) AL_LAST="$2"; shift 2;;
      --json) AL_JSON=1; shift 1;;
      --verify) AL_VERIFY=1; shift 1;;
      -h|--help) command_usage audit-log; exit 0;;
      *) echo "Unknown audit-log flag: $1" >&2; exit 2;;
    esac
  done

  [[ "$AL_LAST" =~ ^[0-9]+$ ]] || { echo "ERROR: --last must be integer" >&2; exit 2; }
  AL_FILE="$(audit_log_path)"
  if [[ ! -f "$AL_FILE" ]]; then
    echo "No audit log found: $AL_FILE" >&2
    exit 1
  fi

  if [[ "$AL_VERIFY" -eq 1 ]]; then
    if [[ "$AL_JSON" -eq 1 ]]; then
      python3 - "$AL_FILE" <<'PY'
import hashlib, json, sys
path = sys.argv[1]
rows = []
errors = []
with open(path, "rb") as f:
    for line_no, raw in enumerate(f, 1):
        s = raw.decode("utf-8", "ignore").strip()
        if not s:
            continue
        try:
            obj = json.loads(s)
        except Exception:
            errors.append(f"line {line_no}: invalid_json")
            continue
        rows.append((line_no, obj))

prev_chain = ""
for line_no, obj in rows:
    stored_prev = str(obj.get("prev_hash", "") or "")
    stored_chain = str(obj.get("chain_hash", "") or "")
    if stored_prev != prev_chain:
        errors.append(f"line {line_no}: prev_hash mismatch")
    base = dict(obj)
    base.pop("prev_hash", None)
    base.pop("chain_hash", None)
    material = (stored_prev + "|" + json.dumps(base, sort_keys=True, separators=(",", ":"))).encode("utf-8", "ignore")
    calc = hashlib.sha256(material).hexdigest()
    if stored_chain != calc:
        errors.append(f"line {line_no}: chain_hash mismatch")
    prev_chain = stored_chain

valid = len(errors) == 0 and len(rows) > 0
print(json.dumps({
    "audit_verify_contract_version": 1,
    "file": path,
    "valid": valid,
    "events_checked": len(rows),
    "errors": errors
}, indent=2, sort_keys=True))
raise SystemExit(0 if valid else 2)
PY
    else
      python3 - "$AL_FILE" <<'PY'
import hashlib, json, sys
path = sys.argv[1]
rows = []
errors = []
with open(path, "rb") as f:
    for line_no, raw in enumerate(f, 1):
        s = raw.decode("utf-8", "ignore").strip()
        if not s:
            continue
        try:
            obj = json.loads(s)
        except Exception:
            errors.append(f"line {line_no}: invalid_json")
            continue
        rows.append((line_no, obj))

prev_chain = ""
for line_no, obj in rows:
    stored_prev = str(obj.get("prev_hash", "") or "")
    stored_chain = str(obj.get("chain_hash", "") or "")
    if stored_prev != prev_chain:
        errors.append(f"line {line_no}: prev_hash mismatch")
    base = dict(obj)
    base.pop("prev_hash", None)
    base.pop("chain_hash", None)
    material = (stored_prev + "|" + json.dumps(base, sort_keys=True, separators=(",", ":"))).encode("utf-8", "ignore")
    calc = hashlib.sha256(material).hexdigest()
    if stored_chain != calc:
        errors.append(f"line {line_no}: chain_hash mismatch")
    prev_chain = stored_chain

valid = len(errors) == 0 and len(rows) > 0
print("=== linux-maint audit-log verify ===")
print(f"file={path}")
print(f"events_checked={len(rows)}")
print(f"valid={str(valid).lower()}")
if errors:
    for e in errors[:20]:
        print(f"- {e}")
raise SystemExit(0 if valid else 2)
PY
    fi
    exit $?
  fi

  if [[ "$AL_JSON" -eq 1 ]]; then
    python3 - "$AL_FILE" "$AL_LAST" <<'PY'
import json, sys
path, last_n = sys.argv[1], int(sys.argv[2])
rows = []
with open(path, "r", encoding="utf-8", errors="ignore") as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            rows.append(json.loads(line))
        except Exception:
            rows.append({"raw": line, "parse_error": True})
rows = rows[-last_n:]
print(json.dumps({"audit_contract_version": 1, "file": path, "events": rows}, indent=2, sort_keys=True))
PY
    exit 0
  fi

  echo "=== linux-maint audit-log ==="
  echo "file=$AL_FILE"
  tail -n "$AL_LAST" "$AL_FILE"
}

linux_maint_cmd_cm_hook() {
  local CM_PROVIDER="" CM_TARGET="localhost" CM_PLAYBOOK=""
  local CM_MODULE="ping" CM_ARGS="" CM_JSON=0 CM_DRY_RUN=0
  local rendered="" rc=0
  local -a cmd=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --provider) CM_PROVIDER="$2"; shift 2;;
      --target) CM_TARGET="$2"; shift 2;;
      --playbook) CM_PLAYBOOK="$2"; shift 2;;
      --module) CM_MODULE="$2"; shift 2;;
      --args) CM_ARGS="$2"; shift 2;;
      --json) CM_JSON=1; shift 1;;
      --dry-run) CM_DRY_RUN=1; shift 1;;
      -h|--help) command_usage cm-hook; exit 0;;
      *) echo "Unknown cm-hook flag: $1" >&2; exit 2;;
    esac
  done

  case "$CM_PROVIDER" in
    ansible|puppet|salt) ;;
    *) echo "ERROR: --provider must be ansible|puppet|salt" >&2; exit 2;;
  esac

  if [[ "$CM_PROVIDER" == "ansible" ]]; then
    if [[ -n "$CM_PLAYBOOK" ]]; then
      cmd=(ansible-playbook -i "${CM_TARGET}," "$CM_PLAYBOOK")
    else
      cmd=(ansible "$CM_TARGET" -m "$CM_MODULE")
      [[ -n "$CM_ARGS" ]] && cmd+=(-a "$CM_ARGS")
    fi
  elif [[ "$CM_PROVIDER" == "puppet" ]]; then
    cmd=(puppet agent -t)
  else
    cmd=(salt "$CM_TARGET" test.ping)
    [[ -n "$CM_ARGS" ]] && cmd=(salt "$CM_TARGET" "$CM_ARGS")
  fi

  rendered="$(printf '%q ' "${cmd[@]}" | sed 's/[[:space:]]$//')"
  audit_log_append "cm-hook" "start" "provider=$CM_PROVIDER target=$CM_TARGET cmd=$rendered dry_run=$CM_DRY_RUN"

  if [[ "$CM_DRY_RUN" -eq 1 ]]; then
    if [[ "$CM_JSON" -eq 1 ]]; then
      python3 - "$CM_PROVIDER" "$CM_TARGET" "$rendered" <<'PY'
import json, sys
provider, target, cmd = sys.argv[1:4]
print(json.dumps({
  "cm_hook_contract_version": 1,
  "provider": provider,
  "target": target,
  "dry_run": True,
  "executed": False,
  "rc": 0,
  "cmd": cmd
}, indent=2, sort_keys=True))
PY
      audit_log_append "cm-hook" "success" "provider=$CM_PROVIDER dry_run=1"
      exit 0
    fi
    echo "DRY_RUN provider=$CM_PROVIDER cmd=$rendered"
    audit_log_append "cm-hook" "success" "provider=$CM_PROVIDER dry_run=1"
    exit 0
  fi

  if ! command -v "${cmd[0]}" >/dev/null 2>&1; then
    echo "ERROR: command not found: ${cmd[0]}" >&2
    audit_log_append "cm-hook" "failure" "provider=$CM_PROVIDER reason=missing_command cmd=${cmd[0]}"
    exit 2
  fi

  set +e
  "${cmd[@]}"
  rc=$?
  set -e
  audit_log_append "cm-hook" "$([[ "$rc" -eq 0 ]] && echo success || echo failure)" "provider=$CM_PROVIDER rc=$rc"
  if [[ "$CM_JSON" -eq 1 ]]; then
    python3 - "$CM_PROVIDER" "$CM_TARGET" "$rendered" "$rc" <<'PY'
import json, sys
provider, target, cmd, rc = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
print(json.dumps({
  "cm_hook_contract_version": 1,
  "provider": provider,
  "target": target,
  "dry_run": False,
  "executed": True,
  "rc": rc,
  "cmd": cmd
}, indent=2, sort_keys=True))
PY
  fi
  exit "$rc"
}
