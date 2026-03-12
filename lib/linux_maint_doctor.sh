#!/usr/bin/env bash
# Doctor command helper for linux-maint.

linux_maint_cmd_doctor() {
  local DOCTOR_LIB_PATH CFG_DIR LOG_DIR_LOCAL SUMMARY_DIR_LOCAL STATE_DIR_LOCAL LOCK_DIR_LOCAL INVENTORY_DIR_LOCAL
  local DOCTOR_INIT_CMD DOCTOR_PREFLIGHT_CMD DOCTOR_RUN_CMD DOCTOR_WRITE_PREFIX
  local DOCTOR_STRICT=0 DOCTOR_JSON=0 DOCTOR_COMPACT=0 DOCTOR_FIX=0 DOCTOR_FIX_DEPS=0 DOCTOR_FIX_OPTIONAL=0 DOCTOR_YES=0 DOCTOR_DRY_RUN=0
  local fix_actions_file="" doctor_json_rc=0 n_hosts="" perm_fail=0 doctor_result="OK"
  local wrapper_path="${wrapper:-}" libexec_path="${LIBEXEC:-}"
  local -a fix_actions=() fix_suggestions=() missing_pkgs=() seen_perm_paths=()

  DOCTOR_LIB_PATH="${LINUX_MAINT_LIB:-$PREFIX/lib/linux_maint.sh}"
  if [[ "$MODE" == "repo" ]]; then
    CFG_DIR="$(linux_maint_effective_cfg_dir)"
    LOG_DIR_LOCAL="$(linux_maint_effective_log_dir)"
    SUMMARY_DIR_LOCAL="$(linux_maint_effective_summary_dir)"
    STATE_DIR_LOCAL="$(linux_maint_effective_state_dir)"
    LOCK_DIR_LOCAL="$(linux_maint_effective_lock_dir)"
    INVENTORY_DIR_LOCAL="${LM_INVENTORY_OUTPUT_DIR:-}"
    DOCTOR_INIT_CMD="linux-maint init"
    DOCTOR_PREFLIGHT_CMD="linux-maint preflight"
    DOCTOR_RUN_CMD="linux-maint run"
    DOCTOR_WRITE_PREFIX=""
  else
    CFG_DIR="$(linux_maint_effective_cfg_dir)"
    LOG_DIR_LOCAL="$(linux_maint_effective_log_dir)"
    SUMMARY_DIR_LOCAL="$(linux_maint_effective_summary_dir)"
    STATE_DIR_LOCAL="$(linux_maint_effective_state_dir)"
    LOCK_DIR_LOCAL="$(linux_maint_effective_lock_dir)"
    INVENTORY_DIR_LOCAL="${LM_INVENTORY_OUTPUT_DIR:-/var/log/inventory}"
    DOCTOR_INIT_CMD="sudo linux-maint init"
    DOCTOR_PREFLIGHT_CMD="sudo linux-maint preflight"
    DOCTOR_RUN_CMD="sudo linux-maint run"
    DOCTOR_WRITE_PREFIX="sudo "
  fi

  if [[ "${LM_STRICT:-0}" == "1" || "${LM_STRICT:-}" == "true" ]]; then
    DOCTOR_STRICT=1
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json) DOCTOR_JSON=1; shift 1;;
      --compact) DOCTOR_COMPACT=1; shift 1;;
      --fix) DOCTOR_FIX=1; shift 1;;
      --fix-deps) DOCTOR_FIX=1; DOCTOR_FIX_DEPS=1; shift 1;;
      --fix-deps-optional) DOCTOR_FIX=1; DOCTOR_FIX_DEPS=1; DOCTOR_FIX_OPTIONAL=1; shift 1;;
      --yes) DOCTOR_YES=1; shift 1;;
      --dry-run) DOCTOR_DRY_RUN=1; shift 1;;
      -h|--help)
        command_usage doctor
        exit 0
        ;;
      *)
        echo "Unknown doctor flag: $1" >&2
        exit 2
        ;;
    esac
  done

  if [[ "$DOCTOR_FIX" -eq 1 ]]; then
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
      if [[ "$MODE" == "installed" || "$DOCTOR_FIX_DEPS" -eq 1 ]]; then
        echo "ERROR: doctor --fix requires root" >&2
        audit_log_append "doctor-fix" "failure" "reason=requires_root mode=$MODE fix_deps=$DOCTOR_FIX_DEPS"
        exit 1
      fi
    fi
    audit_log_append "doctor-fix" "start" "dry_run=$DOCTOR_DRY_RUN fix_deps=$DOCTOR_FIX_DEPS fix_optional=$DOCTOR_FIX_OPTIONAL cfg_dir=$CFG_DIR"
  fi

  record_fix_action() {
    local action="$1" target="$2" status="$3"
    [[ -n "$fix_actions_file" ]] || return 0
    printf '%s\t%s\t%s\n' "$action" "$target" "$status" >> "$fix_actions_file" 2>/dev/null || true
  }

  ensure_dir() {
    local d="$1"
    [[ -n "$d" ]] || return 0
    if [[ ! -d "$d" ]]; then
      if [[ "$DOCTOR_DRY_RUN" -eq 1 ]]; then
        fix_actions+=("would create: $d")
        record_fix_action "create_dir" "$d" "dry_run"
      else
        if install -d -m 0755 "$d" 2>/dev/null; then
          fix_actions+=("create: $d")
          record_fix_action "create_dir" "$d" "ok"
        else
          fix_actions+=("failed: $d")
          record_fix_action "create_dir" "$d" "failed"
        fi
      fi
    elif [[ ! -w "$d" ]]; then
      if [[ "$DOCTOR_DRY_RUN" -eq 1 ]]; then
        fix_actions+=("would chmod: $d")
        record_fix_action "chmod_dir" "$d" "dry_run"
      else
        if chmod 0755 "$d" 2>/dev/null; then
          fix_actions+=("chmod: $d")
          record_fix_action "chmod_dir" "$d" "ok"
        else
          fix_actions+=("failed: $d")
          record_fix_action "chmod_dir" "$d" "failed"
        fi
      fi
    fi
  }

  add_pkg() {
    local pkg="$1"
    [[ -z "$pkg" ]] && return 0
    local p
    for p in "${missing_pkgs[@]:-}"; do
      [[ "$p" == "$pkg" ]] && return 0
    done
    missing_pkgs+=("$pkg")
  }

  add_fix() {
    fix_suggestions+=("$1")
  }

  need_cmd() {
    local dep_cmd="$1" pkg_hint="$2"
    if command -v "$dep_cmd" >/dev/null 2>&1; then
      printf "%-18s %s\n" "$dep_cmd" "${C_GREEN}OK${C_RESET}"
    else
      printf "%-18s %s\n" "$dep_cmd" "${C_RED}MISSING${C_RESET}"
      [[ -n "$pkg_hint" ]] && echo "  hint: install package: $pkg_hint" >&2
      [[ -n "$pkg_hint" ]] && add_fix "Install missing dependency: $pkg_hint"
    fi
  }

  check_perm() {
    local path="$1"
    [[ -n "$path" ]] || return 0
    local seen
    for seen in "${seen_perm_paths[@]:-}"; do
      [[ "$seen" == "$path" ]] && return 0
    done
    seen_perm_paths+=("$path")
    if [[ ! -d "$path" ]]; then
      printf "%-40s %s\n" "$path" "${C_RED}MISSING${C_RESET}"
      return 0
    fi
    local perm group world
    perm="$(stat -c %a "$path" 2>/dev/null || echo "")"
    group=$(( (perm / 10) % 10 ))
    world=$(( perm % 10 ))
    if (( (group & 2) || (world & 2) )); then
      if [[ "$DOCTOR_STRICT" -eq 1 ]]; then
        printf "%-40s %s\n" "$path" "${C_RED}CRIT (group/world writable)${C_RESET}"
        perm_fail=1
      else
        printf "%-40s %s\n" "$path" "${C_YELLOW}WARN (group/world writable)${C_RESET}"
      fi
      add_fix "Remove group/world write from $path (chmod go-w $path)"
    else
      printf "%-40s %s\n" "$path" "${C_GREEN}OK${C_RESET}"
    fi
  }

  if [[ "$DOCTOR_FIX" -eq 1 ]]; then
    if [[ "$DOCTOR_DRY_RUN" -eq 0 && "$DOCTOR_YES" -eq 0 ]]; then
      if [[ -t 1 ]]; then
        echo "About to apply fixes (dirs/perms${DOCTOR_FIX_DEPS:+, deps}). Proceed? [y/N]"
        read -r ans
        [[ "$ans" =~ ^[Yy]$ ]] || {
          echo "Aborted."
          exit 1
        }
      else
        echo "ERROR: doctor --fix requires --yes in non-interactive mode" >&2
        exit 1
      fi
    fi

    fix_actions_file="$(mktemp -p "${TMPDIR:-/tmp}" linux_maint_fix_actions.XXXXXX)"
    ensure_dir "$LOG_DIR_LOCAL"
    ensure_dir "$INVENTORY_DIR_LOCAL"
    ensure_dir "$STATE_DIR_LOCAL"
    ensure_dir "$LOCK_DIR_LOCAL"
    if [[ ! -d "$CFG_DIR" ]]; then
      if [[ "$DOCTOR_DRY_RUN" -eq 1 ]]; then
        fix_actions+=("would create: $CFG_DIR")
        record_fix_action "create_dir" "$CFG_DIR" "dry_run"
      else
        if install -d -m 0755 "$CFG_DIR" 2>/dev/null; then
          fix_actions+=("create: $CFG_DIR")
          record_fix_action "create_dir" "$CFG_DIR" "ok"
        else
          fix_actions+=("failed: $CFG_DIR")
          record_fix_action "create_dir" "$CFG_DIR" "failed"
        fi
      fi
    fi

    if [[ "$DOCTOR_FIX_DEPS" -eq 1 ]]; then
      command -v awk >/dev/null 2>&1 || add_pkg "gawk"
      command -v sed >/dev/null 2>&1 || add_pkg "sed"
      command -v grep >/dev/null 2>&1 || add_pkg "grep"
      command -v df >/dev/null 2>&1 || add_pkg "coreutils"
      command -v find >/dev/null 2>&1 || add_pkg "findutils"
      command -v timeout >/dev/null 2>&1 || add_pkg "coreutils"
      command -v curl >/dev/null 2>&1 || add_pkg "curl"
      command -v openssl >/dev/null 2>&1 || add_pkg "openssl"
      command -v ssh >/dev/null 2>&1 || add_pkg "openssh-clients"
      command -v systemctl >/dev/null 2>&1 || add_pkg "systemd"

      if [[ "$DOCTOR_FIX_OPTIONAL" -eq 1 ]]; then
        command -v chronyc >/dev/null 2>&1 || add_pkg "chrony"
        command -v ntpq >/dev/null 2>&1 || add_pkg "ntp"
        command -v smartctl >/dev/null 2>&1 || add_pkg "smartmontools"
        command -v nvme >/dev/null 2>&1 || add_pkg "nvme-cli"
        command -v netstat >/dev/null 2>&1 || add_pkg "net-tools"
        command -v ss >/dev/null 2>&1 || add_pkg "iproute"
        command -v journalctl >/dev/null 2>&1 || add_pkg "systemd"
      fi

      if [[ "${#missing_pkgs[@]:-0}" -gt 0 ]]; then
        if [[ "$DOCTOR_DRY_RUN" -eq 1 ]]; then
          fix_actions+=("deps: would install ${missing_pkgs[*]}")
          record_fix_action "install_deps" "${missing_pkgs[*]}" "dry_run"
        elif command -v dnf >/dev/null 2>&1; then
          if dnf -y install "${missing_pkgs[@]}"; then
            fix_actions+=("deps: installed via dnf")
            record_fix_action "install_deps" "${missing_pkgs[*]}" "ok"
          else
            fix_actions+=("deps: install failed (dnf)")
            record_fix_action "install_deps" "${missing_pkgs[*]}" "failed"
          fi
        elif command -v yum >/dev/null 2>&1; then
          if yum -y install "${missing_pkgs[@]}"; then
            fix_actions+=("deps: installed via yum")
            record_fix_action "install_deps" "${missing_pkgs[*]}" "ok"
          else
            fix_actions+=("deps: install failed (yum)")
            record_fix_action "install_deps" "${missing_pkgs[*]}" "failed"
          fi
        elif command -v apt-get >/dev/null 2>&1; then
          apt-get update >/dev/null 2>&1 || true
          if apt-get -y install "${missing_pkgs[@]}"; then
            fix_actions+=("deps: installed via apt-get")
            record_fix_action "install_deps" "${missing_pkgs[*]}" "ok"
          else
            fix_actions+=("deps: install failed (apt-get)")
            record_fix_action "install_deps" "${missing_pkgs[*]}" "failed"
          fi
        elif command -v zypper >/dev/null 2>&1; then
          if zypper -n install "${missing_pkgs[@]}"; then
            fix_actions+=("deps: installed via zypper")
            record_fix_action "install_deps" "${missing_pkgs[*]}" "ok"
          else
            fix_actions+=("deps: install failed (zypper)")
            record_fix_action "install_deps" "${missing_pkgs[*]}" "failed"
          fi
        else
          fix_actions+=("deps: no supported package manager found")
          record_fix_action "install_deps" "${missing_pkgs[*]}" "failed"
        fi
      else
        fix_actions+=("deps: none missing")
        record_fix_action "install_deps" "none" "skipped"
      fi
    fi
  fi

  if [[ "$DOCTOR_JSON" -eq 1 ]]; then
    set +e
    MODE="$MODE" PREFIX="$PREFIX" WRAPPER="$wrapper_path" LIBEXEC="$libexec_path" LINUX_MAINT_LIB="$DOCTOR_LIB_PATH" CFG_DIR="$CFG_DIR" LOG_DIR="$LOG_DIR_LOCAL" SUMMARY_DIR="$SUMMARY_DIR_LOCAL" STATE_DIR="$STATE_DIR_LOCAL" LOCK_DIR="$LOCK_DIR_LOCAL" INVENTORY_DIR="$INVENTORY_DIR_LOCAL" DOCTOR_STRICT="$DOCTOR_STRICT" DOCTOR_INIT_CMD="$DOCTOR_INIT_CMD" DOCTOR_PREFLIGHT_CMD="$DOCTOR_PREFLIGHT_CMD" DOCTOR_RUN_CMD="$DOCTOR_RUN_CMD" DOCTOR_WRITE_PREFIX="$DOCTOR_WRITE_PREFIX" FIX_ACTIONS_FILE="$fix_actions_file" python3 - <<'PYJSON'
import json
import os
import pathlib
import shutil
import stat

mode = os.environ.get("MODE", "")
prefix = os.environ.get("PREFIX", "")
wrapper = os.environ.get("WRAPPER", "")
libexec = os.environ.get("LIBEXEC", "")
lib = os.environ.get("LINUX_MAINT_LIB", "")
cfg_dir = os.environ.get("CFG_DIR", "/etc/linux_maint")
log_dir = os.environ.get("LOG_DIR", "/var/log/health")
summary_dir = os.environ.get("SUMMARY_DIR", log_dir)
state_dir = os.environ.get("STATE_DIR", "/var/lib/linux_maint")
lock_dir = os.environ.get("LOCK_DIR", "/var/lock")
inventory_dir = os.environ.get("INVENTORY_DIR", "/var/log/inventory")
strict = os.environ.get("DOCTOR_STRICT", "0") == "1"
init_cmd = os.environ.get("DOCTOR_INIT_CMD", "sudo linux-maint init")
preflight_cmd = os.environ.get("DOCTOR_PREFLIGHT_CMD", "sudo linux-maint preflight")
run_cmd = os.environ.get("DOCTOR_RUN_CMD", "sudo linux-maint run")
write_prefix = os.environ.get("DOCTOR_WRITE_PREFIX", "sudo ")
fix_actions_file = os.environ.get("FIX_ACTIONS_FILE", "")

cfg_path = pathlib.Path(cfg_dir)

def has_cmd(cmd: str) -> bool:
    return shutil.which(cmd) is not None

def active_hosts_count(path: pathlib.Path):
    if not path.is_file():
        return 0, ""
    count = 0
    try:
        for raw in path.read_text(errors="ignore").splitlines():
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            count += 1
    except PermissionError:
        return 0, "permission_denied"
    except OSError as exc:
        return 0, str(exc)
    return count, ""

config_files = ["servers.txt", "excluded.txt", "services.txt", "emails.txt"]
hosts_configured, servers_error = active_hosts_count(cfg_path / "servers.txt")
config = {
    "dir_exists": cfg_path.is_dir(),
    "files": {name: (cfg_path / name).exists() for name in config_files},
    "hosts_configured": hosts_configured,
}
if servers_error:
    config["servers_readable"] = False
    config["servers_error"] = servers_error
else:
    config["servers_readable"] = True

fix_suggestions = []
fix_seen = set()

def add_fix(msg: str) -> None:
    if msg in fix_seen:
        return
    fix_seen.add(msg)
    fix_suggestions.append(msg)

servers_path = cfg_path / "servers.txt"
services_path = cfg_path / "services.txt"
if not cfg_path.is_dir():
    add_fix(f"Initialize config templates: {init_cmd}")
else:
    if not servers_path.exists() or servers_path.stat().st_size == 0:
        add_fix(
            f"Create {cfg_dir}/servers.txt (example: printf '%s\\n' localhost | {write_prefix}tee {cfg_dir}/servers.txt)"
        )
    elif servers_error:
        add_fix(f"Ensure {cfg_dir}/servers.txt is readable")
    elif hosts_configured == 0:
        add_fix(f"Add hosts to {cfg_dir}/servers.txt (one per line)")
    if services_path.exists() and services_path.stat().st_size == 0:
        add_fix(f"Populate {cfg_dir}/services.txt with critical services (one per line)")

gates = [
    ("cert_monitor", "certs.txt"),
    ("network_monitor", "network_targets.txt"),
    ("ports_baseline_monitor", "ports_baseline.txt"),
    ("config_drift_monitor", "config_paths.txt"),
    ("user_monitor", "baseline_users.txt"),
    ("user_monitor", "baseline_sudoers.txt"),
    ("backup_check", "backup_targets.csv"),
]
monitor_gates = []
for mon, fn in gates:
    p = cfg_path / fn
    monitor_gates.append(
        {
            "monitor": mon,
            "path": str(p),
            "present": p.exists() and p.stat().st_size > 0,
        }
    )
    if not (p.exists() and p.stat().st_size > 0):
        if fn == "certs.txt":
            add_fix(f"Add cert paths to {cfg_dir}/certs.txt")
        elif fn == "network_targets.txt":
            add_fix(f"Add network targets to {cfg_dir}/network_targets.txt")
        elif fn == "ports_baseline.txt":
            add_fix(f"Add baseline allowlist to {cfg_dir}/ports_baseline.txt")
        elif fn == "config_paths.txt":
            add_fix(f"Add config paths to {cfg_dir}/config_paths.txt")
        elif fn == "baseline_users.txt":
            add_fix(f"Generate baseline users list at {cfg_dir}/baseline_users.txt")
        elif fn == "baseline_sudoers.txt":
            add_fix(f"Generate baseline sudoers list at {cfg_dir}/baseline_sudoers.txt")
        elif fn == "backup_targets.csv":
            add_fix(f"Add backup targets to {cfg_dir}/backup_targets.csv")

dep_hints = [
    ("awk", "gawk"),
    ("sed", "sed"),
    ("grep", "grep"),
    ("df", "coreutils"),
    ("find", "findutils"),
    ("timeout", "coreutils"),
    ("curl", "curl"),
    ("openssl", "openssl"),
    ("ssh", "openssh-clients"),
    ("systemctl", "systemd"),
]
dependencies = []
for c, h in dep_hints:
    present = has_cmd(c)
    dependencies.append({"cmd": c, "present": present, "hint": h})
    if not present and h:
        add_fix(f"Install missing dependency: {h}")

writable_paths = []
for path in [log_dir, inventory_dir, state_dir, lock_dir]:
    if path and path not in writable_paths:
        writable_paths.append(path)
writable_locations = []
for d in writable_paths:
    p = pathlib.Path(d)
    exists = p.is_dir()
    writable = exists and os.access(d, os.W_OK)
    writable_locations.append({"path": d, "exists": exists, "writable": writable})
    if not exists:
        add_fix(f"Create missing dir: {write_prefix}install -d -m 0755 {d}")
    elif not writable:
        add_fix(f"Ensure {d} is writable (example: {write_prefix}install -d -m 0755 {d})")

dir_permissions = []
for p in [log_dir, summary_dir, state_dir, cfg_dir]:
    path = pathlib.Path(p)
    exists = path.is_dir()
    group_writable = False
    world_writable = False
    if exists:
        try:
            mode_bits = path.stat().st_mode
            group_writable = bool(mode_bits & stat.S_IWGRP)
            world_writable = bool(mode_bits & stat.S_IWOTH)
        except Exception:
            pass
    severity = "OK"
    if not exists:
        severity = "MISSING"
    elif group_writable or world_writable:
        severity = "CRIT" if strict else "WARN"
        add_fix(f"Remove group/world write from {p} (chmod go-w {p})")
    dir_permissions.append(
        {
            "path": p,
            "exists": exists,
            "group_writable": group_writable,
            "world_writable": world_writable,
            "severity": severity,
        }
    )

result = {
    "schema_version": 1,
    "doctor_json_contract_version": 1,
    "mode": mode,
    "prefix": prefix,
    "wrapper": wrapper,
    "libexec": libexec,
    "lib": lib,
    "cfg_dir": cfg_dir,
    "strict": strict,
    "config": config,
    "monitor_gates": monitor_gates,
    "dependencies": dependencies,
    "writable_locations": writable_locations,
    "dir_permissions": dir_permissions,
    "fix_suggestions": fix_suggestions,
    "fix_actions": [],
    "next_actions": [
        "linux-maint verify-install",
        init_cmd,
        preflight_cmd,
        run_cmd,
        "linux-maint pack-logs --out .",
    ],
}

perm_fail = any(item.get("severity") == "CRIT" for item in dir_permissions)
result["ok"] = not perm_fail

if fix_actions_file and os.path.exists(fix_actions_file):
    try:
        with open(fix_actions_file, "r", encoding="utf-8", errors="ignore") as f:
            for i, raw in enumerate(f, start=1):
                line = raw.rstrip("\n")
                if not line:
                    continue
                parts = line.split("\t")
                action = parts[0] if len(parts) > 0 else ""
                target = parts[1] if len(parts) > 1 else ""
                status = parts[2] if len(parts) > 2 else ""
                result["fix_actions"].append(
                    {"id": i, "action": action, "target": target, "status": status}
                )
    except Exception:
        pass

print(json.dumps(result, sort_keys=True))
raise SystemExit(2 if strict and perm_fail else 0)
PYJSON
    doctor_json_rc=$?
    set -e
    if [[ -n "$fix_actions_file" ]]; then
      rm -f "$fix_actions_file" 2>/dev/null || true
    fi
    if [[ "$DOCTOR_FIX" -eq 1 ]]; then
      if [[ "$doctor_json_rc" -eq 0 ]]; then
        audit_log_append "doctor-fix" "success" "json=1 dry_run=$DOCTOR_DRY_RUN"
      else
        audit_log_append "doctor-fix" "failure" "json=1 dry_run=$DOCTOR_DRY_RUN rc=$doctor_json_rc"
      fi
    fi
    exit "$doctor_json_rc"
  fi

  section "linux-maint doctor"
  echo "mode=$MODE"
  echo "prefix=$PREFIX"
  if [[ "$DOCTOR_COMPACT" -eq 1 ]]; then
    echo "note=compact"
    echo ""
  fi
  echo "wrapper=$wrapper_path"
  echo "libexec=$libexec_path"
  echo "lib=$DOCTOR_LIB_PATH"
  echo "cfg_dir=$CFG_DIR"
  echo "strict=$DOCTOR_STRICT"

  if [[ "$DOCTOR_FIX" -eq 1 ]]; then
    echo ""
    section "Fixes applied"
    if [[ "${#fix_actions[@]}" -eq 0 ]]; then
      echo "none"
    else
      local a
      for a in "${fix_actions[@]}"; do
        echo "- $a"
      done
    fi
  fi

  if [[ "$DOCTOR_COMPACT" -eq 0 ]]; then
    echo "== Files =="
    local path
    for path in "$wrapper_path" "$DOCTOR_LIB_PATH"; do
      if [[ -e "$path" ]]; then
        ls -la "$path"
      else
        echo "MISSING: $path"
      fi
    done
    if [[ "$MODE" == "installed" ]]; then
      [[ -d "$libexec_path" ]] && ls -ld "$libexec_path" || echo "MISSING: $libexec_path"
    else
      [[ -d "$REPO_MONITORS" ]] && ls -ld "$REPO_MONITORS" || echo "MISSING: $REPO_MONITORS"
    fi
  fi

  echo ""
  section "Config presence"
  fix_suggestions=()
  if [[ -d "$CFG_DIR" ]]; then
    printf "%-44s %s\n" "FILE" "STATUS"
    local f
    for f in "$CFG_DIR/servers.txt" "$CFG_DIR/excluded.txt" "$CFG_DIR/services.txt" "$CFG_DIR/emails.txt"; do
      if [[ "$f" == "$CFG_DIR/servers.txt" && -e "$f" && ! -r "$f" ]]; then
        printf "%-44s %s\n" "$f" "${C_YELLOW}UNREADABLE${C_RESET}"
      elif [[ -e "$f" ]]; then
        printf "%-44s %s\n" "$f" "${C_GREEN}OK${C_RESET}"
      else
        printf "%-44s %s\n" "$f" "${C_RED}MISSING${C_RESET}"
      fi
    done

    if [[ ! -e "$CFG_DIR/servers.txt" ]]; then
      echo "WARN: servers.txt missing/empty" >&2
      add_fix "Create $CFG_DIR/servers.txt (example: printf '%s\\n' localhost | ${DOCTOR_WRITE_PREFIX}tee $CFG_DIR/servers.txt)"
    elif [[ ! -r "$CFG_DIR/servers.txt" ]]; then
      echo "WARN: servers.txt is unreadable" >&2
      add_fix "Ensure $CFG_DIR/servers.txt is readable"
    elif [[ ! -s "$CFG_DIR/servers.txt" ]]; then
      echo "WARN: servers.txt missing/empty" >&2
      add_fix "Create $CFG_DIR/servers.txt (example: printf '%s\\n' localhost | ${DOCTOR_WRITE_PREFIX}tee $CFG_DIR/servers.txt)"
    else
      n_hosts="$(awk 'BEGIN{c=0} /^[[:space:]]*($|#)/ {next} {c++} END{print c}' "$CFG_DIR/servers.txt" 2>/dev/null || printf '0\n')"
      echo "hosts_configured=$n_hosts"
      if [[ "$n_hosts" -eq 0 ]]; then
        echo "WARN: servers.txt has no active hosts (only comments/blank lines)" >&2
        add_fix "Add hosts to $CFG_DIR/servers.txt (one per line)"
      fi
    fi

    if [[ -f "$CFG_DIR/services.txt" && ! -s "$CFG_DIR/services.txt" ]]; then
      echo "WARN: services.txt is empty; service monitor may be ineffective" >&2
      add_fix "Populate $CFG_DIR/services.txt with critical services (one per line)"
    fi
  else
    echo "MISSING: config dir $CFG_DIR" >&2
    echo "Tip: $DOCTOR_INIT_CMD" >&2
    add_fix "Initialize config templates: $DOCTOR_INIT_CMD"
  fi

  echo ""
  section "Monitor gates (what may SKIP)"
  printf "%-22s %-10s %s\n" "MONITOR" "STATUS" "PATH"
  if [[ -s "$CFG_DIR/certs.txt" ]]; then
    printf "%-22s %-10s %s\n" "cert_monitor" "${C_GREEN}OK${C_RESET}" "$CFG_DIR/certs.txt"
  else
    printf "%-22s %-10s %s\n" "cert_monitor" "${C_RED}MISSING${C_RESET}" "$CFG_DIR/certs.txt"
    add_fix "Add cert paths to $CFG_DIR/certs.txt"
  fi
  if [[ -s "$CFG_DIR/network_targets.txt" ]]; then
    printf "%-22s %-10s %s\n" "network_monitor" "${C_GREEN}OK${C_RESET}" "$CFG_DIR/network_targets.txt"
  else
    printf "%-22s %-10s %s\n" "network_monitor" "${C_RED}MISSING${C_RESET}" "$CFG_DIR/network_targets.txt"
    add_fix "Add network targets to $CFG_DIR/network_targets.txt"
  fi
  if [[ -s "$CFG_DIR/ports_baseline.txt" ]]; then
    printf "%-22s %-10s %s\n" "ports_baseline_monitor" "${C_GREEN}OK${C_RESET}" "$CFG_DIR/ports_baseline.txt"
  else
    printf "%-22s %-10s %s\n" "ports_baseline_monitor" "${C_RED}MISSING${C_RESET}" "$CFG_DIR/ports_baseline.txt"
    add_fix "Add baseline allowlist to $CFG_DIR/ports_baseline.txt"
  fi
  if [[ -s "$CFG_DIR/config_paths.txt" ]]; then
    printf "%-22s %-10s %s\n" "config_drift_monitor" "${C_GREEN}OK${C_RESET}" "$CFG_DIR/config_paths.txt"
  else
    printf "%-22s %-10s %s\n" "config_drift_monitor" "${C_RED}MISSING${C_RESET}" "$CFG_DIR/config_paths.txt"
    add_fix "Add config paths to $CFG_DIR/config_paths.txt"
  fi
  if [[ -s "$CFG_DIR/baseline_users.txt" ]]; then
    printf "%-22s %-10s %s\n" "user_monitor(users)" "${C_GREEN}OK${C_RESET}" "$CFG_DIR/baseline_users.txt"
  else
    printf "%-22s %-10s %s\n" "user_monitor(users)" "${C_RED}MISSING${C_RESET}" "$CFG_DIR/baseline_users.txt"
    add_fix "Generate baseline users list at $CFG_DIR/baseline_users.txt"
  fi
  if [[ -s "$CFG_DIR/baseline_sudoers.txt" ]]; then
    printf "%-22s %-10s %s\n" "user_monitor(sudoers)" "${C_GREEN}OK${C_RESET}" "$CFG_DIR/baseline_sudoers.txt"
  else
    printf "%-22s %-10s %s\n" "user_monitor(sudoers)" "${C_RED}MISSING${C_RESET}" "$CFG_DIR/baseline_sudoers.txt"
    add_fix "Generate baseline sudoers list at $CFG_DIR/baseline_sudoers.txt"
  fi
  if [[ -s "$CFG_DIR/backup_targets.csv" ]]; then
    printf "%-22s %-10s %s\n" "backup_check" "${C_GREEN}OK${C_RESET}" "$CFG_DIR/backup_targets.csv"
  else
    printf "%-22s %-10s %s\n" "backup_check" "${C_RED}MISSING${C_RESET}" "$CFG_DIR/backup_targets.csv"
    add_fix "Add backup targets to $CFG_DIR/backup_targets.csv"
  fi

  echo ""
  section "Dependencies (best-effort)"
  need_cmd awk "gawk"
  need_cmd sed "sed"
  need_cmd grep "grep"
  need_cmd df "coreutils"
  need_cmd find "findutils"
  need_cmd timeout "coreutils"
  need_cmd curl "curl"
  need_cmd openssl "openssl"
  need_cmd ssh "openssh-clients"
  need_cmd systemctl "systemd"

  if [[ "$DOCTOR_COMPACT" -eq 0 ]]; then
    echo ""
    section "systemd (best-effort)"
    if command -v systemctl >/dev/null 2>&1; then
      local unit
      for unit in linux-maint.timer linux-maint.service; do
        if systemctl list-unit-files --no-legend "$unit" 2>/dev/null | grep -q "^$unit"; then
          echo "UNIT: $unit"
          systemctl is-enabled "$unit" 2>/dev/null || true
          systemctl is-active "$unit" 2>/dev/null || true
        else
          echo "INFO: unit not installed: $unit"
        fi
      done
      echo "-- timers (linux-maint) --"
      systemctl list-timers --all --no-pager 2>/dev/null | grep -E "linux-maint\.timer|NEXT|^$" || true
    else
      echo "INFO: systemctl not found"
    fi
  fi

  echo ""
  section "Can write state/logs?"
  printf "%-24s %s\n" "PATH" "STATUS"
  local d
  for d in "$LOG_DIR_LOCAL" "$INVENTORY_DIR_LOCAL" "$STATE_DIR_LOCAL" "$LOCK_DIR_LOCAL"; do
    [[ -n "$d" ]] || continue
    if [[ -d "$d" ]]; then
      if [[ -w "$d" ]]; then
        printf "%-24s %s\n" "$d" "${C_GREEN}OK${C_RESET}"
      else
        printf "%-24s %s\n" "$d" "${C_RED}NOT_WRITABLE${C_RESET}"
      fi
      if [[ ! -w "$d" ]]; then
        add_fix "Ensure $d is writable (example: ${DOCTOR_WRITE_PREFIX}install -d -m 0755 $d)"
      fi
    else
      printf "%-24s %s\n" "$d" "${C_RED}MISSING${C_RESET}"
      add_fix "Create missing dir: ${DOCTOR_WRITE_PREFIX}install -d -m 0755 $d"
    fi
  done

  echo ""
  section "Directory permissions"
  perm_fail=0
  seen_perm_paths=()
  check_perm "$LOG_DIR_LOCAL"
  check_perm "$SUMMARY_DIR_LOCAL"
  check_perm "$STATE_DIR_LOCAL"
  check_perm "$CFG_DIR"

  echo ""
  section "Fix suggestions"
  if [[ "${#fix_suggestions[@]}" -eq 0 ]]; then
    echo "- none"
  else
    local f
    for f in "${fix_suggestions[@]}"; do
      echo "- $f"
    done
  fi

  if [[ "${#fix_suggestions[@]}" -gt 0 ]]; then
    doctor_result="WARN"
  fi
  if [[ "${perm_fail:-0}" -eq 1 ]]; then
    if [[ "$DOCTOR_STRICT" -eq 1 ]]; then
      doctor_result="CRIT"
    else
      doctor_result="WARN"
    fi
  fi

  echo ""
  echo "== Guidance =="
  echo "warnings=${#fix_suggestions[@]}"
  echo "next_step: linux-maint verify-install"
  if [[ ! -d "$CFG_DIR" || ! -s "$CFG_DIR/servers.txt" ]]; then
    echo "next_step: $DOCTOR_INIT_CMD"
  fi
  echo "next_step: $DOCTOR_PREFLIGHT_CMD"
  echo "next_step: $DOCTOR_RUN_CMD"
  if [[ "$DOCTOR_COMPACT" -eq 0 ]]; then
    echo "next_step: linux-maint pack-logs --out ."
  fi

  echo ""
  echo "== Summary =="
  echo "strict=$DOCTOR_STRICT"
  echo "fix_suggestions=${#fix_suggestions[@]}"
  echo "permission_failures=${perm_fail:-0}"
  echo "result=$doctor_result"
  case "$doctor_result" in
    OK) echo "${C_GREEN}doctor ok${C_RESET}" ;;
    WARN) echo "${C_YELLOW}doctor warn${C_RESET}" ;;
    *) echo "${C_RED}doctor crit${C_RESET}" ;;
  esac

  if [[ -n "$fix_actions_file" ]]; then
    rm -f "$fix_actions_file" 2>/dev/null || true
  fi
  if [[ "$DOCTOR_STRICT" -eq 1 && "${perm_fail:-0}" -eq 1 ]]; then
    if [[ "$DOCTOR_FIX" -eq 1 ]]; then
      audit_log_append "doctor-fix" "failure" "strict=1 perm_fail=1"
    fi
    exit 2
  fi
  if [[ "$DOCTOR_FIX" -eq 1 ]]; then
    audit_log_append "doctor-fix" "success" "json=0 dry_run=$DOCTOR_DRY_RUN"
  fi
}
