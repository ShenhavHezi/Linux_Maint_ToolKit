#!/usr/bin/env bash
# Diagnostics command helpers for linux-maint.

linux_maint_cmd_self_check() {
  local SC_JSON=0 SC_COMPACT=0 SC_STRICT=0
  local CFG_DIR LOG_DIR_SC STATE_DIR_SC LOCK_DIR_SC
  local sc_failures=0 purpose d dep

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json) SC_JSON=1; shift 1;;
      --compact) SC_COMPACT=1; shift 1;;
      --strict) SC_STRICT=1; shift 1;;
      -h|--help)
        command_usage self-check
        exit 0;;
      *) echo "Unknown self-check flag: $1" >&2; exit 2;;
    esac
  done

  CFG_DIR="$(linux_maint_effective_cfg_dir)"
  LOG_DIR_SC="$(linux_maint_effective_log_dir)"
  STATE_DIR_SC="$(linux_maint_effective_state_dir /tmp /var/lib/linux_maint)"
  LOCK_DIR_SC="$(linux_maint_effective_lock_dir /tmp /var/lock)"

  if [[ "$SC_JSON" -eq 1 ]]; then
    MODE="$MODE" CFG_DIR="$CFG_DIR" LOG_DIR_SC="$LOG_DIR_SC" STATE_DIR_SC="$STATE_DIR_SC" LOCK_DIR_SC="$LOCK_DIR_SC" SC_STRICT="$SC_STRICT" python3 - <<'PY'
import json, os, pathlib, shutil, sys

mode = os.environ.get("MODE","")
cfg_dir = os.environ.get("CFG_DIR","/etc/linux_maint")
log_dir = os.environ.get("LOG_DIR_SC","/var/log/health")
state_dir = os.environ.get("STATE_DIR_SC","/var/lib/linux_maint")
lock_dir = os.environ.get("LOCK_DIR_SC","/var/lock")
strict = os.environ.get("SC_STRICT","0") == "1"

cfg_path = pathlib.Path(cfg_dir)
config_files = ["servers.txt", "excluded.txt", "services.txt"]
config = {
    "dir_exists": cfg_path.is_dir(),
    "files": {name: (cfg_path / name).exists() for name in config_files},
}

def writable(path: str) -> bool:
    p = pathlib.Path(path)
    if not p.is_dir():
        return False
    return os.access(path, os.W_OK)

paths = [
    {"purpose": "logs", "path": log_dir, "exists": pathlib.Path(log_dir).is_dir(), "writable": writable(log_dir)},
    {"purpose": "state", "path": state_dir, "exists": pathlib.Path(state_dir).is_dir(), "writable": writable(state_dir)},
    {"purpose": "lock", "path": lock_dir, "exists": pathlib.Path(lock_dir).is_dir(), "writable": writable(lock_dir)},
]

deps_list = ["bash","awk","sed","grep","df","find","timeout","ssh"]
deps = [{"cmd": d, "present": shutil.which(d) is not None} for d in deps_list]

missing_cfg = (not config["dir_exists"]) or any(not v for v in config["files"].values())
bad_paths = any((not p["exists"]) or (not p["writable"]) for p in paths)
missing_deps = any(not d["present"] for d in deps)
ok = not (missing_cfg or bad_paths or missing_deps)

out = {
    "schema_version": 1,
    "self_check_json_contract_version": 1,
    "mode": mode,
    "strict": strict,
    "ok": ok,
    "cfg_dir": cfg_dir,
    "config": config,
    "paths": paths,
    "dependencies": deps,
}

print(json.dumps(out, sort_keys=True))
if strict and not ok:
    raise SystemExit(2)
PY
    exit $?
  fi

  section "linux-maint self-check"
  echo "mode=$MODE"
  echo "cfg_dir=$CFG_DIR"
  if [[ "$SC_COMPACT" -eq 1 ]]; then
    echo "note=compact"
    echo ""
  fi
  section "Config files"
  printf "%-44s %s\n" "FILE" "STATUS"
  for f in "$CFG_DIR/servers.txt" "$CFG_DIR/excluded.txt" "$CFG_DIR/services.txt"; do
    if [[ -e "$f" ]]; then
      printf "%-44s %s\n" "$f" "${C_GREEN}OK${C_RESET}"
    else
      printf "%-44s %s\n" "$f" "${C_RED}MISSING${C_RESET}"
      sc_failures=$((sc_failures+1))
    fi
  done
  if [[ "$SC_COMPACT" -eq 0 ]]; then
    echo ""
    section "Paths (writable)"
    printf "%-10s %-44s %s\n" "PURPOSE" "PATH" "STATUS"
    for purpose in logs state lock; do
      case "$purpose" in
        logs) d="$LOG_DIR_SC" ;;
        state) d="$STATE_DIR_SC" ;;
        lock) d="$LOCK_DIR_SC" ;;
      esac
      if [[ -d "$d" ]]; then
        if [[ -w "$d" ]]; then
          printf "%-10s %-44s %s\n" "$purpose" "$d" "${C_GREEN}OK${C_RESET}"
        else
          printf "%-10s %-44s %s\n" "$purpose" "$d" "${C_RED}NOT_WRITABLE${C_RESET}"
          sc_failures=$((sc_failures+1))
        fi
      else
        printf "%-10s %-44s %s\n" "$purpose" "$d" "${C_RED}MISSING${C_RESET}"
        sc_failures=$((sc_failures+1))
      fi
    done
    echo ""
    section "Dependencies"
    for dep in bash awk sed grep df find timeout ssh; do
      if command -v "$dep" >/dev/null 2>&1; then
        printf "%-18s %s\n" "$dep" "${C_GREEN}OK${C_RESET}"
      else
        printf "%-18s %s\n" "$dep" "${C_RED}MISSING${C_RESET}"
        sc_failures=$((sc_failures+1))
      fi
    done
  fi
  if [[ "$SC_STRICT" -eq 1 && "$sc_failures" -gt 0 ]]; then
    echo ""
    echo "self-check strict failed: $sc_failures issue(s)"
    exit 2
  fi
}

linux_maint_cmd_security_profile() {
  local SP_JSON=0 SP_STRICT=0 SP_FIPS=0
  local CFG_DIR LOG_DIR_SP STATE_DIR_SP LOCK_DIR_SP

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json) SP_JSON=1; shift 1;;
      --strict) SP_STRICT=1; shift 1;;
      --fips) SP_FIPS=1; shift 1;;
      -h|--help)
        command_usage security-profile
        exit 0;;
      *) echo "Unknown security-profile flag: $1" >&2; exit 2;;
    esac
  done

  CFG_DIR="$(linux_maint_effective_cfg_dir)"
  LOG_DIR_SP="$(linux_maint_effective_log_dir)"
  STATE_DIR_SP="$(linux_maint_effective_state_dir /tmp /var/lib/linux_maint)"
  LOCK_DIR_SP="$(linux_maint_effective_lock_dir /tmp /var/lock)"

  MODE="$MODE" CFG_DIR="$CFG_DIR" LOG_DIR_SP="$LOG_DIR_SP" STATE_DIR_SP="$STATE_DIR_SP" LOCK_DIR_SP="$LOCK_DIR_SP" SP_JSON="$SP_JSON" SP_STRICT="$SP_STRICT" SP_FIPS="$SP_FIPS" python3 - <<'PY'
import json, os, pathlib, shutil, stat, sys
import re

mode = os.environ.get("MODE","")
cfg_dir = os.environ.get("CFG_DIR","/etc/linux_maint")
log_dir = os.environ.get("LOG_DIR_SP","/var/log/health")
state_dir = os.environ.get("STATE_DIR_SP","/var/lib/linux_maint")
lock_dir = os.environ.get("LOCK_DIR_SP","/var/lock")
json_mode = os.environ.get("SP_JSON","0") == "1"
strict = os.environ.get("SP_STRICT","0") == "1"
fips_requested = os.environ.get("SP_FIPS","0") == "1"

def path_mode(path):
    p = pathlib.Path(path)
    if not p.exists():
        return None
    try:
        return stat.S_IMODE(p.stat().st_mode)
    except Exception:
        return None

def bad_perms(path):
    mode = path_mode(path)
    if mode is None:
        return "missing"
    if mode & stat.S_IWOTH:
        return "world_writable"
    if mode & stat.S_IWGRP:
        return "group_writable"
    return "ok"

def truthy(value):
    return str(value).strip().lower() in ("1", "true", "yes", "on", "enabled")

def falsey(value):
    return str(value).strip().lower() in ("0", "false", "no", "off", "disabled")

def detect_fips_enabled():
    override = os.environ.get("LM_FIPS_ENABLED")
    if override is not None:
        if truthy(override):
            return True, "env_override=enabled"
        if falsey(override):
            return False, "env_override=disabled"
        return None, f"env_override=invalid:{override}"

    status_file = pathlib.Path(os.environ.get("LM_FIPS_STATUS_FILE", "/proc/sys/crypto/fips_enabled"))
    try:
        value = status_file.read_text(encoding="utf-8").strip()
    except FileNotFoundError:
        return False, f"status_file_missing:{status_file}"
    except PermissionError:
        return None, f"status_file_unreadable:{status_file}"
    except Exception as exc:
        return None, f"status_file_error:{type(exc).__name__}"

    if value == "1":
        return True, f"status_file={status_file}"
    if value == "0":
        return False, f"status_file={status_file}"
    return None, f"status_file_invalid:{status_file}:{value}"

def weak_ssh_crypto_detail(ssh_opts):
    if not ssh_opts.strip():
        return ""
    patterns = {
        "weak_ciphers": r"Ciphers=.*(3des-cbc|arcfour|arcfour128|arcfour256|aes128-cbc|aes192-cbc|aes256-cbc|blowfish-cbc|cast128-cbc|rijndael-cbc@lysator\.liu\.se)",
        "weak_kex": r"KexAlgorithms=.*(diffie-hellman-group1-sha1|diffie-hellman-group14-sha1|diffie-hellman-group-exchange-sha1)",
        "weak_macs": r"MACs=.*(hmac-md5|hmac-md5-96|hmac-sha1|hmac-sha1-96|umac-64@openssh\.com)",
    }
    for name, pattern in patterns.items():
        if re.search(pattern, ssh_opts, flags=re.IGNORECASE):
            return name
    return ""

ssh_mode = os.environ.get("LM_SSH_KNOWN_HOSTS_MODE","accept-new")
allowlist_strict = os.environ.get("LM_SSH_ALLOWLIST_STRICT","0").lower() in ("1","true","yes","on")
fips_enabled, fips_detail = detect_fips_enabled()

checks = []
def add(name, ok, detail=""):
    checks.append({"check": name, "ok": bool(ok), "detail": detail})

for p in [cfg_dir, log_dir, state_dir, lock_dir]:
    status = bad_perms(p)
    add(f"path_perm:{p}", status == "ok", status)

add("ssh_known_hosts_mode", ssh_mode == "strict", f"mode={ssh_mode}")
add("ssh_allowlist_strict", allowlist_strict, f"enabled={allowlist_strict}")
add("gpg_present", shutil.which("gpg") is not None, "required for signed artifact workflows")
add("sha256sum_present", shutil.which("sha256sum") is not None, "required for integrity checks")

if fips_requested:
    add("fips_mode_enabled", fips_enabled is True, fips_detail)
    add("fips_sha256sum_present", shutil.which("sha256sum") is not None, "required for FIPS-friendly integrity checks")
    weak_detail = weak_ssh_crypto_detail(os.environ.get("LM_SSH_OPTS", ""))
    add("fips_ssh_opts_no_weak_crypto", weak_detail == "", weak_detail or "no weak SSH crypto overrides detected")

ok = all(c["ok"] for c in checks)
out = {
    "schema_version": 1,
    "security_profile_contract_version": 1,
    "mode": mode,
    "strict": strict,
    "fips_requested": fips_requested,
    "fips_enabled": fips_enabled,
    "ok": ok,
    "checks": checks,
}

if json_mode:
    print(json.dumps(out, indent=2, sort_keys=True))
else:
    print("=== linux-maint security-profile ===")
    print(f"mode={mode}")
    for c in checks:
        st = "OK" if c["ok"] else "FAIL"
        print(f"{c['check']}: {st} ({c.get('detail','')})")
    print(f"overall={'OK' if ok else 'FAIL'}")

if strict and not ok:
    raise SystemExit(2)
PY
}

linux_maint_cmd_deps() {
  local mon req opt c req_avail req_total opt_avail opt_total
  has_cmd() { command -v "$1" >/dev/null 2>&1 && echo yes || echo no; }

  if [[ "$MODE" == "installed" ]]; then
    need_root_for deps
  fi

  section "linux-maint deps"
  echo "mode=$MODE"
  echo "format: monitor|required|optional|available_required|available_optional"

  while IFS='|' read -r mon req opt; do
    [[ -z "$mon" ]] && continue
    req_avail=0; req_total=0
    opt_avail=0; opt_total=0

    for c in $req; do
      req_total=$((req_total+1))
      [[ "$(has_cmd "$c")" == "yes" ]] && req_avail=$((req_avail+1))
    done
    for c in $opt; do
      opt_total=$((opt_total+1))
      [[ "$(has_cmd "$c")" == "yes" ]] && opt_avail=$((opt_avail+1))
    done

    echo "monitor=$mon|required=${req:-none}|optional=${opt:-none}|available_required=${req_avail}/${req_total}|available_optional=${opt_avail}/${opt_total}"
  done <<'EOF_DEPS'
preflight_check|awk sed grep df timeout ssh|curl openssl
config_validate|awk sed grep|none
health_monitor|awk sed grep ps df|none
inode_monitor|awk sed grep df|none
disk_trend_monitor|awk sed grep df|none
network_monitor|awk sed grep|curl
service_monitor|awk sed grep|systemctl
ntp_drift_monitor|awk sed grep|chronyc ntpq
patch_monitor|awk sed grep|apt yum dnf zypper
storage_health_monitor|awk sed grep|smartctl nvme
kernel_events_monitor|awk sed grep|journalctl dmesg
cert_monitor|awk sed grep|openssl
nfs_mount_monitor|awk sed grep|showmount
ports_baseline_monitor|awk sed grep|ss netstat
config_drift_monitor|awk sed grep|sha256sum md5sum
user_monitor|awk sed grep|id getent
backup_check|awk sed grep|none
inventory_export|awk sed grep hostname|ip lsblk lscpu
EOF_DEPS
}
