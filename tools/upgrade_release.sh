#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: linux-maint upgrade <tarball> [flags]

Flags:
  --check                  inspect the tarball only; no install
  --plan                   inspect upgrade impact; no install
  --json                   with --check/--plan, emit machine-readable assessment
  --sums FILE              checksum file for verify-release
  --sig FILE               detached signature for verify-release
  --rollback-tarball FILE  known-good rollback artifact to record in the manifest
  --prefix PATH            install prefix (default: active installed prefix)
  --cfg-dir PATH           config dir to preserve and snapshot
  --log-dir PATH           log dir for post-upgrade verify-install
  --state-dir PATH         state dir for manifests and post-upgrade verify-install
  --with-user              pass through to install.sh
  --with-timer             pass through to install.sh
  --with-logrotate         pass through to install.sh
  --dry-run                verify and snapshot only; do not run install.sh
  --keep-workdir           keep extracted workdir for inspection
EOF
}

bool_is_true() {
  case "${1:-0}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

need_root() {
  if bool_is_true "${LM_UPGRADE_SKIP_ROOT_CHECK:-0}"; then
    return 0
  fi
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "ERROR: linux-maint upgrade requires root." >&2
    echo "Hint: sudo linux-maint upgrade <tarball> --sums dist/SHA256SUMS" >&2
    exit 1
  fi
}

iso_now() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

read_build_kv() {
  local path="$1" key="$2"
  [[ -f "$path" ]] || return 0
  awk -F= -v key="$key" '$1 == key { print $2; exit }' "$path"
}

sha256_file() {
  local path="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$path" | awk '{print $1}'
  fi
}

version_relation() {
  python3 - "$1" "$2" <<'PY'
import sys

def parse(v):
    try:
        return tuple(int(x) for x in v.split("."))
    except Exception:
        return None

current, target = sys.argv[1:3]
if not current or not target:
    print("unknown")
    raise SystemExit(0)
cv = parse(current)
tv = parse(target)
if cv is None or tv is None:
    print("unknown")
elif tv > cv:
    print("upgrade")
elif tv < cv:
    print("downgrade")
else:
    print("same")
PY
}

extract_release_notes_section() {
  local notes_path="$1" section_name="$2" limit="${3:-3}"
  [[ -f "$notes_path" ]] || return 0
  python3 - "$notes_path" "$section_name" "$limit" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
section_name = sys.argv[2]
limit = int(sys.argv[3])
lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
in_highlights = False
count = 0
for line in lines:
    stripped = line.strip()
    if stripped == f"## {section_name}":
        in_highlights = True
        continue
    if in_highlights and stripped.startswith("## "):
        break
    if in_highlights and stripped.startswith("- "):
        print(stripped[2:])
        count += 1
        if count >= limit:
            break
if count == 0 and section_name.lower() == "compatibility notes":
    in_upgrade_section = False
    in_compat_list = False
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("## "):
            in_upgrade_section = stripped.lower() == "## upgrade and compatibility notes"
            in_compat_list = False
            continue
        if not in_upgrade_section:
            continue
        if stripped == "- Compatibility notes:":
            in_compat_list = True
            continue
        if in_compat_list and stripped.startswith("- ") and line.startswith("  "):
            print(stripped[2:])
            count += 1
            if count >= limit:
                break
        elif in_compat_list and stripped.startswith("- ") and not line.startswith("  "):
            break
PY
}

extract_release_notes_metadata() {
  local notes_path="$1"
  [[ -f "$notes_path" ]] || return 0
  python3 - "$notes_path" <<'PY'
import json
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
meta = {"date_utc": None, "version": None, "git_tag": None}
for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
    line = raw.strip()
    m = re.match(r"^- Version:\s*(.+)$", line)
    if m:
        meta["version"] = m.group(1).strip()
        continue
    m = re.match(r"^- Date \(UTC\):\s*(.+)$", line)
    if m:
        meta["date_utc"] = m.group(1).strip()
        continue
    m = re.match(r"^- Git tag:\s*(.+)$", line)
    if m:
        meta["git_tag"] = m.group(1).strip()
print(json.dumps(meta, sort_keys=True))
PY
}

emit_upgrade_check() {
  local tarball="$1" current_version="$2" target_version="$3" notes_path="$4" json_out="$5"
  local relation upgrade_guide note_rel result checks_json release_meta_json
  local target_date_utc="" release_notes_found=0 upgrade_guide_found=0
  local -a warnings=() highlights=() compatibility_notes=() next_steps=()
  relation="$(version_relation "$current_version" "$target_version")"
  upgrade_guide="$EXTRACTED_TREE_PATH/docs/UPGRADE.md"
  if [[ -f "$notes_path" ]]; then
    release_notes_found=1
    mapfile -t highlights < <(extract_release_notes_section "$notes_path" "Highlights" 4)
    mapfile -t compatibility_notes < <(extract_release_notes_section "$notes_path" "Compatibility notes" 4)
    release_meta_json="$(extract_release_notes_metadata "$notes_path")"
    target_date_utc="$(
      RELEASE_META_JSON="$release_meta_json" python3 - <<'PY'
import json, os
payload = json.loads(os.environ.get("RELEASE_META_JSON", "{}"))
print(payload.get("date_utc") or "")
PY
    )"
  fi
  [[ -f "$upgrade_guide" ]] && upgrade_guide_found=1
  if [[ "$relation" == "downgrade" ]]; then
    warnings+=("target release is older than the installed version")
  elif [[ "$relation" == "same" ]]; then
    warnings+=("target release matches the installed version")
  elif [[ "$relation" == "unknown" ]]; then
    warnings+=("unable to compare installed and target versions")
  fi
  [[ -f "$notes_path" ]] || warnings+=("release notes for the target version were not found in the tarball")
  [[ -f "$upgrade_guide" ]] || warnings+=("upgrade guide missing from the tarball")
  note_rel=""
  if [[ -f "$notes_path" ]]; then
    note_rel="${notes_path#"$EXTRACTED_TREE_PATH"/}"
  fi
  if [[ "${#warnings[@]}" -gt 0 ]]; then
    result="WARN"
  else
    result="OK"
  fi
  if [[ "$result" == "OK" ]]; then
    next_steps+=("sudo linux-maint upgrade $tarball${SUMS_FILE:+ --sums $SUMS_FILE}")
  else
    if [[ "$relation" == "same" ]]; then
      next_steps+=("choose a newer release tarball before upgrading")
    elif [[ "$relation" == "downgrade" ]]; then
      next_steps+=("confirm you intend a rollback before proceeding")
    fi
    next_steps+=("review the target release notes and upgrade guide")
    next_steps+=("sudo linux-maint upgrade $tarball${SUMS_FILE:+ --sums $SUMS_FILE}")
  fi
  checks_json="$(
    RELEASE_NOTES_FOUND="$release_notes_found" \
    UPGRADE_GUIDE_FOUND="$upgrade_guide_found" \
    SUMS_FILE_PATH="$SUMS_FILE" \
    SIG_FILE_PATH="$SIG_FILE" \
    python3 - <<'PY'
import json, os
print(json.dumps({
    "release_notes_found": os.environ.get("RELEASE_NOTES_FOUND") == "1",
    "upgrade_guide_found": os.environ.get("UPGRADE_GUIDE_FOUND") == "1",
    "sums_supplied": bool(os.environ.get("SUMS_FILE_PATH")),
    "sig_supplied": bool(os.environ.get("SIG_FILE_PATH")),
}, sort_keys=True))
PY
  )"
  if [[ "$json_out" -eq 1 ]]; then
    CURRENT_VERSION="$current_version" \
    TARGET_VERSION="$target_version" \
    RELATION="$relation" \
    TARBALL_PATH="$tarball" \
    NOTES_PATH="$notes_path" \
    NOTE_REL="$note_rel" \
    UPGRADE_GUIDE="$upgrade_guide" \
    TARGET_DATE_UTC="$target_date_utc" \
    CHECKS_JSON="$checks_json" \
    RESULT="$result" \
    WARNINGS_JOINED="$(printf '%s\n' "${warnings[@]}")" \
    HIGHLIGHTS_JOINED="$(printf '%s\n' "${highlights[@]}")" \
    COMPAT_JOINED="$(printf '%s\n' "${compatibility_notes[@]}")" \
    NEXT_STEPS_JOINED="$(printf '%s\n' "${next_steps[@]}")" \
    python3 - <<'PY'
import json
import os

payload = {
    "schema_version": 1,
    "upgrade_check_json_contract_version": 1,
    "tarball": os.environ.get("TARBALL_PATH", ""),
    "current_version": os.environ.get("CURRENT_VERSION") or None,
    "target_version": os.environ.get("TARGET_VERSION") or None,
    "relation": os.environ.get("RELATION", "unknown"),
    "target_date_utc": os.environ.get("TARGET_DATE_UTC") or None,
    "release_notes": os.environ.get("NOTES_PATH") or None,
    "release_notes_rel": os.environ.get("NOTE_REL") or None,
    "upgrade_guide": os.environ.get("UPGRADE_GUIDE") or None,
    "checks": json.loads(os.environ.get("CHECKS_JSON", "{}")),
    "highlights": [x for x in os.environ.get("HIGHLIGHTS_JOINED", "").splitlines() if x],
    "compatibility_notes": [x for x in os.environ.get("COMPAT_JOINED", "").splitlines() if x],
    "warnings": [x for x in os.environ.get("WARNINGS_JOINED", "").splitlines() if x],
    "next_steps": [x for x in os.environ.get("NEXT_STEPS_JOINED", "").splitlines() if x],
    "result": os.environ.get("RESULT", "WARN"),
}
print(json.dumps(payload, indent=2, sort_keys=True))
PY
  else
    echo "linux-maint upgrade --check"
    echo "tarball=$tarball"
    echo "current_version=${current_version:-unknown}"
    echo "target_version=${target_version:-unknown}"
    echo "relation=$relation"
    [[ -n "$target_date_utc" ]] && echo "target_date_utc=$target_date_utc"
    if [[ -f "$notes_path" ]]; then
      echo "release_notes=$notes_path"
    fi
    if [[ -f "$upgrade_guide" ]]; then
      echo "upgrade_guide=$upgrade_guide"
    fi
    echo "checks: release_notes=$([[ "$release_notes_found" -eq 1 ]] && echo ok || echo missing) upgrade_guide=$([[ "$upgrade_guide_found" -eq 1 ]] && echo ok || echo missing) sums=$([[ -n "$SUMS_FILE" ]] && echo yes || echo no) sig=$([[ -n "$SIG_FILE" ]] && echo yes || echo no)"
    if [[ "${#highlights[@]}" -gt 0 ]]; then
      echo ""
      echo "Highlights:"
      printf -- "- %s\n" "${highlights[@]}"
    fi
    if [[ "${#compatibility_notes[@]}" -gt 0 ]]; then
      echo ""
      echo "Compatibility notes:"
      printf -- "- %s\n" "${compatibility_notes[@]}"
    fi
    if [[ "${#warnings[@]}" -gt 0 ]]; then
      echo ""
      echo "Warnings:"
      printf -- "- %s\n" "${warnings[@]}"
    fi
    echo ""
    echo "== Guidance =="
    printf 'next_step: %s\n' "${next_steps[@]}"
    echo ""
    echo "== Summary =="
    echo "current_version=${current_version:-unknown}"
    echo "target_version=${target_version:-unknown}"
    echo "relation=$relation"
    echo "target_date_utc=${target_date_utc:-unknown}"
    echo "highlights=${#highlights[@]}"
    echo "warnings=${#warnings[@]}"
    echo "result=$result"
    echo "upgrade check ${result,,}"
  fi
}

count_files_under() {
  local path="$1"
  if [[ -d "$path" && -r "$path" ]]; then
    find "$path" -type f 2>/dev/null | wc -l | awk '{print $1}'
  else
    echo 0
  fi
}

emit_upgrade_plan() {
  local tarball="$1" current_version="$2" target_version="$3" notes_path="$4" json_out="$5"
  local relation upgrade_guide note_rel result checks_json release_meta_json
  local target_date_utc="" release_notes_found=0 upgrade_guide_found=0 install_sh_found=0 rollback_tarball_supplied=0
  local cfg_exists=0 cfg_readable=0 inventory_meta_present=0 systemctl_present=0 current_service_file=0 current_timer_file=0 current_logrotate_file=0
  local config_file_count=0 conf_d_file_count=0 rollback_score=0 rollback_max_score=3
  local rollback_state="" service_effect="" logrotate_effect=""
  local service_path="$INSTALL_SYSTEMD_DIR/linux-maint.service"
  local timer_path="$INSTALL_SYSTEMD_DIR/linux-maint.timer"
  local logrotate_path="$INSTALL_LOGROTATE_FILE"
  local -a warnings=() highlights=() compatibility_notes=() next_steps=()

  relation="$(version_relation "$current_version" "$target_version")"
  upgrade_guide="$EXTRACTED_TREE_PATH/docs/UPGRADE.md"
  [[ -x "$EXTRACTED_TREE_PATH/install.sh" ]] && install_sh_found=1
  if [[ -f "$notes_path" ]]; then
    release_notes_found=1
    mapfile -t highlights < <(extract_release_notes_section "$notes_path" "Highlights" 4)
    mapfile -t compatibility_notes < <(extract_release_notes_section "$notes_path" "Compatibility notes" 4)
    release_meta_json="$(extract_release_notes_metadata "$notes_path")"
    target_date_utc="$(
      RELEASE_META_JSON="$release_meta_json" python3 - <<'PY'
import json, os
payload = json.loads(os.environ.get("RELEASE_META_JSON", "{}"))
print(payload.get("date_utc") or "")
PY
    )"
  fi
  [[ -f "$upgrade_guide" ]] && upgrade_guide_found=1
  [[ -n "$ROLLBACK_TARBALL" ]] && rollback_tarball_supplied=1

  if [[ -d "$CFG_DIR" ]]; then
    cfg_exists=1
    [[ -r "$CFG_DIR" ]] && cfg_readable=1
  fi
  if [[ -f "$CFG_DIR/inventory_meta.csv" ]]; then
    inventory_meta_present=1
  fi
  config_file_count="$(count_files_under "$CFG_DIR")"
  conf_d_file_count="$(count_files_under "$CFG_DIR/conf.d")"
  if command -v systemctl >/dev/null 2>&1; then
    systemctl_present=1
  fi
  [[ -f "$service_path" ]] && current_service_file=1
  [[ -f "$timer_path" ]] && current_timer_file=1
  [[ -f "$logrotate_path" ]] && current_logrotate_file=1

  if [[ "$WITH_TIMER" -eq 1 ]]; then
    service_effect="install_or_refresh_timer"
  elif [[ "$current_service_file" -eq 1 || "$current_timer_file" -eq 1 ]]; then
    service_effect="keep_existing_units"
  else
    service_effect="no_systemd_changes"
  fi
  if [[ "$WITH_LOGROTATE" -eq 1 ]]; then
    logrotate_effect="install_or_refresh_logrotate"
  elif [[ "$current_logrotate_file" -eq 1 ]]; then
    logrotate_effect="keep_existing_logrotate"
  else
    logrotate_effect="no_logrotate_changes"
  fi

  if [[ "$relation" == "downgrade" ]]; then
    warnings+=("target release is older than the installed version")
  elif [[ "$relation" == "same" ]]; then
    warnings+=("target release matches the installed version")
  elif [[ "$relation" == "unknown" ]]; then
    warnings+=("unable to compare installed and target versions")
  fi
  [[ -f "$notes_path" ]] || warnings+=("release notes for the target version were not found in the tarball")
  [[ -f "$upgrade_guide" ]] || warnings+=("upgrade guide missing from the tarball")
  [[ -x "$EXTRACTED_TREE_PATH/install.sh" ]] || warnings+=("install.sh missing from the tarball")
  if [[ "$cfg_exists" -eq 0 ]]; then
    warnings+=("config dir is missing; upgrade will not add local inventory or overrides")
  elif [[ "$cfg_readable" -eq 0 ]]; then
    warnings+=("config dir is not readable; config snapshot inputs are incomplete")
  fi
  if [[ "$rollback_tarball_supplied" -eq 0 ]]; then
    warnings+=("no rollback tarball supplied; rollback will rely on a separately managed trusted artifact")
  fi
  if [[ "$WITH_TIMER" -eq 1 && "$systemctl_present" -eq 0 ]]; then
    warnings+=("systemctl not found; unit files can be written but the timer will not be enabled automatically")
  fi

  [[ -n "$SUMS_FILE" ]] && rollback_score=$((rollback_score + 1))
  [[ "$rollback_tarball_supplied" -eq 1 ]] && rollback_score=$((rollback_score + 1))
  [[ "$cfg_readable" -eq 1 ]] && rollback_score=$((rollback_score + 1))
  case "$rollback_score" in
    3) rollback_state="ready" ;;
    2) rollback_state="partial" ;;
    *) rollback_state="minimal" ;;
  esac

  note_rel=""
  if [[ -f "$notes_path" ]]; then
    note_rel="${notes_path#"$EXTRACTED_TREE_PATH"/}"
  fi
  if [[ "${#warnings[@]}" -gt 0 ]]; then
    result="WARN"
  else
    result="OK"
  fi

  next_steps+=("review config impact and service/logrotate changes before running the upgrade")
  if [[ "$rollback_tarball_supplied" -eq 0 ]]; then
    next_steps+=("rerun with --rollback-tarball <trusted-previous-release> for stronger rollback readiness")
  fi
  next_steps+=("sudo linux-maint upgrade $tarball${SUMS_FILE:+ --sums $SUMS_FILE}")

  checks_json="$(
    RELEASE_NOTES_FOUND="$release_notes_found" \
    UPGRADE_GUIDE_FOUND="$upgrade_guide_found" \
    INSTALL_SH_FOUND="$install_sh_found" \
    SUMS_FILE_PATH="$SUMS_FILE" \
    SIG_FILE_PATH="$SIG_FILE" \
    ROLLBACK_TARBALL_PATH="$ROLLBACK_TARBALL" \
    python3 - <<'PY'
import json, os
print(json.dumps({
    "release_notes_found": os.environ.get("RELEASE_NOTES_FOUND") == "1",
    "upgrade_guide_found": os.environ.get("UPGRADE_GUIDE_FOUND") == "1",
    "install_sh_found": os.environ.get("INSTALL_SH_FOUND") == "1",
    "sums_supplied": bool(os.environ.get("SUMS_FILE_PATH")),
    "sig_supplied": bool(os.environ.get("SIG_FILE_PATH")),
    "rollback_tarball_supplied": bool(os.environ.get("ROLLBACK_TARBALL_PATH")),
}, sort_keys=True))
PY
  )"

  if [[ "$json_out" -eq 1 ]]; then
    CURRENT_VERSION="$current_version" \
    TARGET_VERSION="$target_version" \
    RELATION="$relation" \
    TARBALL_PATH="$tarball" \
    NOTES_PATH="$notes_path" \
    NOTE_REL="$note_rel" \
    UPGRADE_GUIDE="$upgrade_guide" \
    TARGET_DATE_UTC="$target_date_utc" \
    CHECKS_JSON="$checks_json" \
    RESULT="$result" \
    WARNINGS_JOINED="$(printf '%s\n' "${warnings[@]}")" \
    HIGHLIGHTS_JOINED="$(printf '%s\n' "${highlights[@]}")" \
    COMPAT_JOINED="$(printf '%s\n' "${compatibility_notes[@]}")" \
    NEXT_STEPS_JOINED="$(printf '%s\n' "${next_steps[@]}")" \
    CFG_DIR_PATH="$CFG_DIR" \
    CFG_EXISTS="$cfg_exists" \
    CFG_READABLE="$cfg_readable" \
    CONFIG_FILE_COUNT="$config_file_count" \
    CONF_D_FILE_COUNT="$conf_d_file_count" \
    INVENTORY_META_PRESENT="$inventory_meta_present" \
    SYSTEMD_UNIT_DIR="$INSTALL_SYSTEMD_DIR" \
    SYSTEMCTL_PRESENT="$systemctl_present" \
    CURRENT_SERVICE_FILE="$current_service_file" \
    CURRENT_TIMER_FILE="$current_timer_file" \
    WITH_TIMER_REQUESTED="$WITH_TIMER" \
    SERVICE_EFFECT="$service_effect" \
    LOGROTATE_PATH="$logrotate_path" \
    CURRENT_LOGROTATE_FILE="$current_logrotate_file" \
    WITH_LOGROTATE_REQUESTED="$WITH_LOGROTATE" \
    LOGROTATE_EFFECT="$logrotate_effect" \
    ROLLBACK_STATE="$rollback_state" \
    ROLLBACK_SCORE="$rollback_score" \
    ROLLBACK_MAX="$rollback_max_score" \
    python3 - <<'PY'
import json
import os

payload = {
    "schema_version": 1,
    "upgrade_plan_json_contract_version": 1,
    "tarball": os.environ.get("TARBALL_PATH", ""),
    "current_version": os.environ.get("CURRENT_VERSION") or None,
    "target_version": os.environ.get("TARGET_VERSION") or None,
    "relation": os.environ.get("RELATION", "unknown"),
    "target_date_utc": os.environ.get("TARGET_DATE_UTC") or None,
    "release_notes": os.environ.get("NOTES_PATH") or None,
    "release_notes_rel": os.environ.get("NOTE_REL") or None,
    "upgrade_guide": os.environ.get("UPGRADE_GUIDE") or None,
    "checks": json.loads(os.environ.get("CHECKS_JSON", "{}")),
    "highlights": [x for x in os.environ.get("HIGHLIGHTS_JOINED", "").splitlines() if x],
    "compatibility_notes": [x for x in os.environ.get("COMPAT_JOINED", "").splitlines() if x],
    "warnings": [x for x in os.environ.get("WARNINGS_JOINED", "").splitlines() if x],
    "next_steps": [x for x in os.environ.get("NEXT_STEPS_JOINED", "").splitlines() if x],
    "config": {
        "cfg_dir": os.environ.get("CFG_DIR_PATH", ""),
        "exists": os.environ.get("CFG_EXISTS") == "1",
        "readable": os.environ.get("CFG_READABLE") == "1",
        "file_count": int(os.environ.get("CONFIG_FILE_COUNT", "0") or 0),
        "conf_d_files": int(os.environ.get("CONF_D_FILE_COUNT", "0") or 0),
        "inventory_meta_present": os.environ.get("INVENTORY_META_PRESENT") == "1",
    },
    "service": {
        "systemd_unit_dir": os.environ.get("SYSTEMD_UNIT_DIR", ""),
        "systemctl_present": os.environ.get("SYSTEMCTL_PRESENT") == "1",
        "current_service_file": os.environ.get("CURRENT_SERVICE_FILE") == "1",
        "current_timer_file": os.environ.get("CURRENT_TIMER_FILE") == "1",
        "with_timer_requested": os.environ.get("WITH_TIMER_REQUESTED") == "1",
        "planned_effect": os.environ.get("SERVICE_EFFECT", ""),
    },
    "logrotate": {
        "path": os.environ.get("LOGROTATE_PATH", ""),
        "current_file": os.environ.get("CURRENT_LOGROTATE_FILE") == "1",
        "with_logrotate_requested": os.environ.get("WITH_LOGROTATE_REQUESTED") == "1",
        "planned_effect": os.environ.get("LOGROTATE_EFFECT", ""),
    },
    "rollback_readiness": {
        "state": os.environ.get("ROLLBACK_STATE", "minimal"),
        "score": int(os.environ.get("ROLLBACK_SCORE", "0") or 0),
        "max_score": int(os.environ.get("ROLLBACK_MAX", "0") or 0),
        "checksums_supplied": json.loads(os.environ.get("CHECKS_JSON", "{}")).get("sums_supplied", False),
        "rollback_artifact_supplied": json.loads(os.environ.get("CHECKS_JSON", "{}")).get("rollback_tarball_supplied", False),
        "config_readable": os.environ.get("CFG_READABLE") == "1",
    },
    "result": os.environ.get("RESULT", "WARN"),
}
print(json.dumps(payload, indent=2, sort_keys=True))
PY
  else
    echo "linux-maint upgrade --plan"
    echo "tarball=$tarball"
    echo "current_version=${current_version:-unknown}"
    echo "target_version=${target_version:-unknown}"
    echo "relation=$relation"
    [[ -n "$target_date_utc" ]] && echo "target_date_utc=$target_date_utc"
    if [[ -f "$notes_path" ]]; then
      echo "release_notes=$notes_path"
    fi
    if [[ -f "$upgrade_guide" ]]; then
      echo "upgrade_guide=$upgrade_guide"
    fi
    echo "checks: release_notes=$([[ "$release_notes_found" -eq 1 ]] && echo ok || echo missing) upgrade_guide=$([[ "$upgrade_guide_found" -eq 1 ]] && echo ok || echo missing) install_sh=$([[ "$install_sh_found" -eq 1 ]] && echo ok || echo missing) sums=$([[ -n "$SUMS_FILE" ]] && echo yes || echo no) sig=$([[ -n "$SIG_FILE" ]] && echo yes || echo no) rollback_artifact=$([[ "$rollback_tarball_supplied" -eq 1 ]] && echo yes || echo no)"
    if [[ "${#highlights[@]}" -gt 0 ]]; then
      echo ""
      echo "Highlights:"
      printf -- "- %s\n" "${highlights[@]}"
    fi
    if [[ "${#compatibility_notes[@]}" -gt 0 ]]; then
      echo ""
      echo "Compatibility notes:"
      printf -- "- %s\n" "${compatibility_notes[@]}"
    fi
    echo ""
    echo "Config impact:"
    echo "- cfg_dir=$CFG_DIR"
    echo "- readable=$([[ "$cfg_readable" -eq 1 ]] && echo yes || echo no) files=$config_file_count conf_d_files=$conf_d_file_count inventory_meta=$([[ "$inventory_meta_present" -eq 1 ]] && echo yes || echo no)"
    echo "- upgrade preserves existing config files; snapshot source is assessed before the live upgrade"
    echo ""
    echo "Service impact:"
    echo "- systemd_unit_dir=$INSTALL_SYSTEMD_DIR"
    echo "- current_service_file=$([[ "$current_service_file" -eq 1 ]] && echo yes || echo no) current_timer_file=$([[ "$current_timer_file" -eq 1 ]] && echo yes || echo no) systemctl=$([[ "$systemctl_present" -eq 1 ]] && echo yes || echo no)"
    echo "- planned_effect=$service_effect"
    echo ""
    echo "Logrotate impact:"
    echo "- path=$logrotate_path"
    echo "- current_file=$([[ "$current_logrotate_file" -eq 1 ]] && echo yes || echo no) planned_effect=$logrotate_effect"
    echo ""
    echo "Rollback readiness:"
    echo "- state=$rollback_state score=$rollback_score/$rollback_max_score"
    echo "- checksums=$([[ -n "$SUMS_FILE" ]] && echo yes || echo no) rollback_artifact=$([[ "$rollback_tarball_supplied" -eq 1 ]] && echo yes || echo no) config_readable=$([[ "$cfg_readable" -eq 1 ]] && echo yes || echo no)"
    if [[ "${#warnings[@]}" -gt 0 ]]; then
      echo ""
      echo "Warnings:"
      printf -- "- %s\n" "${warnings[@]}"
    fi
    echo ""
    echo "== Guidance =="
    printf 'next_step: %s\n' "${next_steps[@]}"
    echo ""
    echo "== Summary =="
    echo "current_version=${current_version:-unknown}"
    echo "target_version=${target_version:-unknown}"
    echo "relation=$relation"
    echo "rollback_readiness=$rollback_state"
    echo "warnings=${#warnings[@]}"
    echo "result=$result"
    echo "upgrade plan ${result,,}"
  fi
}

write_text_file() {
  local path="$1" content="$2"
  printf '%s\n' "$content" > "$path"
}

write_payload_inventory() {
  local prefix="$1" out="$2"
  {
    echo "prefix=$prefix"
    echo "generated_at=$(iso_now)"
    echo ""
    for rel in \
      "bin/linux-maint" \
      "sbin/run_full_health_monitor.sh" \
      "libexec/linux_maint" \
      "share/linux_maint" \
      "share/Linux_Maint_ToolKit"
    do
      path="$prefix/$rel"
      if [[ -d "$path" ]]; then
        find "$path" -mindepth 1 -printf '%P\n' 2>/dev/null | sed "s#^#$rel/#" | sort
      elif [[ -e "$path" ]]; then
        printf '%s\n' "$rel"
      fi
    done
    if [[ -d "$prefix/lib" ]]; then
      find "$prefix/lib" -maxdepth 1 -type f -name 'linux_maint*.sh' -printf 'lib/%f\n' | LC_ALL=C sort
    fi
  } > "$out"
}

snapshot_config_dir() {
  local cfg_dir="$1" dest="$2"
  if [[ -d "$cfg_dir" ]]; then
    tar -C "$(dirname "$cfg_dir")" -czf "$dest" "$(basename "$cfg_dir")"
  else
    write_text_file "$dest.absent" "config dir missing at snapshot time: $cfg_dir"
  fi
}

write_rollback_instructions() {
  local path="$1" rollback_tarball="$2" prefix="$3"
  {
    echo "linux-maint rollback guidance"
    echo "generated_at=$(iso_now)"
    echo "prefix=$prefix"
    echo ""
    if [[ -n "$rollback_tarball" ]]; then
      echo "known_good_artifact=$rollback_tarball"
      echo "Suggested rollback:"
      echo "  sudo linux-maint upgrade $rollback_tarball"
    else
      echo "known_good_artifact=(not provided)"
      echo "Suggested rollback:"
      echo "  reinstall the last trusted release tarball"
    fi
    echo "After rollback:"
    echo "  sudo linux-maint verify-install"
    echo "  sudo linux-maint check"
  } > "$path"
}

write_manifest() {
  MANIFEST_STATUS="$MANIFEST_STATUS" \
  STARTED_AT="$STARTED_AT" \
  FINISHED_AT="$FINISHED_AT" \
  MODE_NAME="$MODE_NAME" \
  PREFIX_PATH="$PREFIX_PATH" \
  CFG_DIR_PATH="$CFG_DIR_PATH" \
  LOG_DIR_PATH="$LOG_DIR_PATH" \
  STATE_DIR_PATH="$STATE_DIR_PATH" \
  TARBALL_PATH="$TARBALL_PATH" \
  TARBALL_SHA256="$TARBALL_SHA256" \
  SUMS_FILE_PATH="$SUMS_FILE_PATH" \
  SIG_FILE_PATH="$SIG_FILE_PATH" \
  ROLLBACK_TARBALL_PATH="$ROLLBACK_TARBALL_PATH" \
  MANIFEST_DIR_PATH="$MANIFEST_DIR_PATH" \
  CONFIG_SNAPSHOT_PATH="$CONFIG_SNAPSHOT_PATH" \
  PAYLOAD_INVENTORY_PATH="$PAYLOAD_INVENTORY_PATH" \
  ROLLBACK_INSTRUCTIONS_PATH="$ROLLBACK_INSTRUCTIONS_PATH" \
  WORKDIR_PATH="$WORKDIR_PATH" \
  EXTRACTED_TREE_PATH="$EXTRACTED_TREE_PATH" \
  CURRENT_VERSION_VALUE="$CURRENT_VERSION_VALUE" \
  CURRENT_COMMIT_VALUE="$CURRENT_COMMIT_VALUE" \
  TARGET_VERSION_VALUE="$TARGET_VERSION_VALUE" \
  TARGET_COMMIT_VALUE="$TARGET_COMMIT_VALUE" \
  INSTALL_FLAGS_JOINED="$INSTALL_FLAGS_JOINED" \
  VERIFY_RELEASE_RC_VALUE="$VERIFY_RELEASE_RC_VALUE" \
  INSTALL_RC_VALUE="$INSTALL_RC_VALUE" \
  VERIFY_INSTALL_RC_VALUE="$VERIFY_INSTALL_RC_VALUE" \
  UPGRADE_RC_VALUE="$UPGRADE_RC_VALUE" \
  DRY_RUN_VALUE="$DRY_RUN_VALUE" \
  python3 - "$MANIFEST_FILE" <<'PY'
import json
import os
import sys

def maybe_int(name):
    raw = os.environ.get(name, "")
    if raw == "":
        return None
    try:
        return int(raw)
    except Exception:
        return raw

path = sys.argv[1]
out = {
    "schema_version": 1,
    "upgrade_manifest_version": 1,
    "status": os.environ.get("MANIFEST_STATUS", "unknown"),
    "started_at_utc": os.environ.get("STARTED_AT", ""),
    "finished_at_utc": os.environ.get("FINISHED_AT", ""),
    "mode": os.environ.get("MODE_NAME", "installed"),
    "prefix": os.environ.get("PREFIX_PATH", ""),
    "cfg_dir": os.environ.get("CFG_DIR_PATH", ""),
    "log_dir": os.environ.get("LOG_DIR_PATH", ""),
    "state_dir": os.environ.get("STATE_DIR_PATH", ""),
    "tarball": os.environ.get("TARBALL_PATH", ""),
    "tarball_sha256": os.environ.get("TARBALL_SHA256", ""),
    "sums_file": os.environ.get("SUMS_FILE_PATH") or None,
    "sig_file": os.environ.get("SIG_FILE_PATH") or None,
    "rollback_artifact": os.environ.get("ROLLBACK_TARBALL_PATH") or None,
    "manifest_dir": os.environ.get("MANIFEST_DIR_PATH", ""),
    "config_snapshot": os.environ.get("CONFIG_SNAPSHOT_PATH") or None,
    "payload_inventory": os.environ.get("PAYLOAD_INVENTORY_PATH") or None,
    "rollback_instructions": os.environ.get("ROLLBACK_INSTRUCTIONS_PATH") or None,
    "workdir": os.environ.get("WORKDIR_PATH") or None,
    "extracted_tree": os.environ.get("EXTRACTED_TREE_PATH") or None,
    "current_version": os.environ.get("CURRENT_VERSION_VALUE") or None,
    "current_commit": os.environ.get("CURRENT_COMMIT_VALUE") or None,
    "target_version": os.environ.get("TARGET_VERSION_VALUE") or None,
    "target_commit": os.environ.get("TARGET_COMMIT_VALUE") or None,
    "install_flags": [x for x in os.environ.get("INSTALL_FLAGS_JOINED", "").split("\n") if x],
    "verify_release_rc": maybe_int("VERIFY_RELEASE_RC_VALUE"),
    "install_rc": maybe_int("INSTALL_RC_VALUE"),
    "verify_install_rc": maybe_int("VERIFY_INSTALL_RC_VALUE"),
    "upgrade_rc": maybe_int("UPGRADE_RC_VALUE"),
    "dry_run": os.environ.get("DRY_RUN_VALUE", "0") == "1",
}
with open(path, "w", encoding="utf-8") as fh:
    json.dump(out, fh, indent=2, sort_keys=True)
    fh.write("\n")
PY
}

TARBALL="${1:-}"
[[ -n "$TARBALL" ]] || { usage >&2; exit 2; }
shift || true

SUMS_FILE=""
SIG_FILE=""
ROLLBACK_TARBALL=""
PREFIX="${LINUX_MAINT_PREFIX:-${PREFIX:-/usr/local}}"
CFG_DIR="${LM_CFG_DIR:-/etc/linux_maint}"
LOG_DIR="${LOG_DIR:-/var/log/health}"
STATE_DIR="${LM_STATE_DIR:-/var/lib/linux_maint}"
INSTALL_SYSTEMD_DIR="${LM_INSTALL_SYSTEMD_DIR:-/etc/systemd/system}"
INSTALL_LOGROTATE_FILE="${LM_INSTALL_LOGROTATE_FILE:-/etc/logrotate.d/linux_maint}"
WITH_USER=0
WITH_TIMER=0
WITH_LOGROTATE=0
DRY_RUN=0
KEEP_WORKDIR=0
CHECK_ONLY=0
PLAN_ONLY=0
JSON_OUT=0
VERIFY_TOOL="${LINUX_MAINT_UPGRADE_VERIFY_TOOL:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/verify_release.sh}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) CHECK_ONLY=1; shift ;;
    --plan) PLAN_ONLY=1; shift ;;
    --json) JSON_OUT=1; shift ;;
    --sums) SUMS_FILE="$2"; shift 2 ;;
    --sig) SIG_FILE="$2"; shift 2 ;;
    --rollback-tarball) ROLLBACK_TARBALL="$2"; shift 2 ;;
    --prefix) PREFIX="$2"; shift 2 ;;
    --cfg-dir) CFG_DIR="$2"; shift 2 ;;
    --log-dir) LOG_DIR="$2"; shift 2 ;;
    --state-dir) STATE_DIR="$2"; shift 2 ;;
    --with-user) WITH_USER=1; shift ;;
    --with-timer) WITH_TIMER=1; shift ;;
    --with-logrotate) WITH_LOGROTATE=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --keep-workdir) KEEP_WORKDIR=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown upgrade flag: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -f "$TARBALL" ]] || { echo "ERROR: tarball not found: $TARBALL" >&2; exit 1; }
[[ -x "$VERIFY_TOOL" ]] || { echo "ERROR: verify-release helper not found: $VERIFY_TOOL" >&2; exit 1; }
if [[ -n "$ROLLBACK_TARBALL" && ! -f "$ROLLBACK_TARBALL" ]]; then
  echo "ERROR: rollback tarball not found: $ROLLBACK_TARBALL" >&2
  exit 1
fi

if [[ "$CHECK_ONLY" -eq 1 && "$PLAN_ONLY" -eq 1 ]]; then
  echo "ERROR: use either --check or --plan, not both" >&2
  exit 2
fi
if [[ "$JSON_OUT" -eq 1 && "$CHECK_ONLY" -ne 1 && "$PLAN_ONLY" -ne 1 ]]; then
  echo "ERROR: --json is only supported with --check/--plan" >&2
  exit 2
fi
if [[ "$CHECK_ONLY" -eq 1 && "$DRY_RUN" -eq 1 ]]; then
  echo "ERROR: use either --check or --dry-run, not both" >&2
  exit 2
fi
if [[ "$PLAN_ONLY" -eq 1 && "$DRY_RUN" -eq 1 ]]; then
  echo "ERROR: use either --plan or --dry-run, not both" >&2
  exit 2
fi

if [[ "$CHECK_ONLY" -ne 1 && "$PLAN_ONLY" -ne 1 ]]; then
  need_root
  mkdir -p "$STATE_DIR/upgrades"
  run_id="$(date -u +%Y%m%dT%H%M%SZ)-$$"
  MANIFEST_DIR="$STATE_DIR/upgrades/$run_id"
  mkdir -p "$MANIFEST_DIR"
  ln -sfn "$MANIFEST_DIR" "$STATE_DIR/upgrades/latest" 2>/dev/null || true
else
  MANIFEST_DIR=""
fi

MANIFEST_FILE="$MANIFEST_DIR/upgrade_manifest.json"
CONFIG_SNAPSHOT="$MANIFEST_DIR/config_snapshot.tgz"
PAYLOAD_INVENTORY="$MANIFEST_DIR/installed_payload_inventory.txt"
ROLLBACK_INSTRUCTIONS="$MANIFEST_DIR/rollback_instructions.txt"

STARTED_AT="$(iso_now)"
FINISHED_AT=""
MANIFEST_STATUS="starting"
VERIFY_RELEASE_RC_VALUE=""
INSTALL_RC_VALUE=""
VERIFY_INSTALL_RC_VALUE=""
UPGRADE_RC_VALUE=""
WORKDIR_PATH=""
EXTRACTED_TREE_PATH=""
CURRENT_VERSION_VALUE="$(head -n 1 "$PREFIX/share/linux_maint/VERSION" 2>/dev/null | tr -d '[:space:]' || true)"
CURRENT_COMMIT_VALUE="$(read_build_kv "$PREFIX/share/linux_maint/BUILD_INFO" commit)"
TARGET_VERSION_VALUE=""
TARGET_COMMIT_VALUE=""
TARBALL_PATH="$(cd -- "$(dirname -- "$TARBALL")" && pwd)/$(basename -- "$TARBALL")"
TARBALL_SHA256="$(sha256_file "$TARBALL" || true)"
SUMS_FILE_PATH="${SUMS_FILE:-}"
SIG_FILE_PATH="${SIG_FILE:-}"
ROLLBACK_TARBALL_PATH="${ROLLBACK_TARBALL:-}"
PREFIX_PATH="$PREFIX"
CFG_DIR_PATH="$CFG_DIR"
LOG_DIR_PATH="$LOG_DIR"
STATE_DIR_PATH="$STATE_DIR"
MANIFEST_DIR_PATH="$MANIFEST_DIR"
CONFIG_SNAPSHOT_PATH="$CONFIG_SNAPSHOT"
PAYLOAD_INVENTORY_PATH="$PAYLOAD_INVENTORY"
ROLLBACK_INSTRUCTIONS_PATH="$ROLLBACK_INSTRUCTIONS"
MODE_NAME="installed"
DRY_RUN_VALUE="$DRY_RUN"

install_flags=("--prefix" "$PREFIX")
if [[ "$WITH_USER" -eq 1 ]]; then
  install_flags+=("--with-user")
fi
if [[ "$WITH_TIMER" -eq 1 ]]; then
  install_flags+=("--with-timer")
fi
if [[ "$WITH_LOGROTATE" -eq 1 ]]; then
  install_flags+=("--with-logrotate")
fi
INSTALL_FLAGS_JOINED="$(printf '%s\n' "${install_flags[@]}")"

cleanup_upgrade() {
  local rc=$?
  UPGRADE_RC_VALUE="$rc"
  FINISHED_AT="$(iso_now)"
  if [[ "$CHECK_ONLY" -eq 1 || "$PLAN_ONLY" -eq 1 ]]; then
    if [[ -n "$WORKDIR_PATH" && -d "$WORKDIR_PATH" && "$KEEP_WORKDIR" -eq 0 ]]; then
      rm -rf "$WORKDIR_PATH" 2>/dev/null || true
    fi
    exit "$rc"
  fi
  if [[ "$rc" -ne 0 && "$MANIFEST_STATUS" == "starting" ]]; then
    MANIFEST_STATUS="failed"
  fi
  write_manifest
  if [[ -n "$WORKDIR_PATH" && -d "$WORKDIR_PATH" && "$KEEP_WORKDIR" -eq 0 ]]; then
    rm -rf "$WORKDIR_PATH" 2>/dev/null || true
  fi
  exit "$rc"
}
trap cleanup_upgrade EXIT

if [[ "$CHECK_ONLY" -ne 1 && "$PLAN_ONLY" -ne 1 ]]; then
  snapshot_config_dir "$CFG_DIR" "$CONFIG_SNAPSHOT"
  if [[ ! -f "$CONFIG_SNAPSHOT" && -f "$CONFIG_SNAPSHOT.absent" ]]; then
    CONFIG_SNAPSHOT_PATH="$CONFIG_SNAPSHOT.absent"
  fi
  write_payload_inventory "$PREFIX" "$PAYLOAD_INVENTORY"
  write_rollback_instructions "$ROLLBACK_INSTRUCTIONS" "$ROLLBACK_TARBALL" "$PREFIX"
  write_manifest
fi

verify_args=("$TARBALL")
if [[ -n "$SUMS_FILE" ]]; then
  verify_args+=("--sums" "$SUMS_FILE")
fi
if [[ -n "$SIG_FILE" ]]; then
  verify_args+=("--sig" "$SIG_FILE")
fi

set +e
"$VERIFY_TOOL" "${verify_args[@]}" >/dev/null
VERIFY_RELEASE_RC_VALUE=$?
set -e
if [[ "$VERIFY_RELEASE_RC_VALUE" -ne 0 ]]; then
  MANIFEST_STATUS="failed"
  echo "ERROR: verify-release failed for $TARBALL" >&2
  exit "$VERIFY_RELEASE_RC_VALUE"
fi

WORKDIR_PATH="$(mktemp -d -p "${TMPDIR:-/tmp}" linux_maint_upgrade.XXXXXX)"
EXTRACTED_TREE_PATH="$WORKDIR_PATH/extracted"
mkdir -p "$EXTRACTED_TREE_PATH"
tar -xzf "$TARBALL" -C "$EXTRACTED_TREE_PATH"

TARGET_VERSION_VALUE="$(head -n 1 "$EXTRACTED_TREE_PATH/VERSION" 2>/dev/null | tr -d '[:space:]' || true)"
TARGET_COMMIT_VALUE="$(read_build_kv "$EXTRACTED_TREE_PATH/BUILD_INFO" commit)"
NOTES_PATH="$EXTRACTED_TREE_PATH/docs/release_notes/release_notes_v${TARGET_VERSION_VALUE}.md"
if [[ "$CHECK_ONLY" -eq 1 ]]; then
  emit_upgrade_check "$TARBALL_PATH" "$CURRENT_VERSION_VALUE" "$TARGET_VERSION_VALUE" "$NOTES_PATH" "$JSON_OUT"
  exit 0
fi
if [[ "$PLAN_ONLY" -eq 1 ]]; then
  emit_upgrade_plan "$TARBALL_PATH" "$CURRENT_VERSION_VALUE" "$TARGET_VERSION_VALUE" "$NOTES_PATH" "$JSON_OUT"
  exit 0
fi
MANIFEST_STATUS="verified"
write_manifest

echo "linux-maint upgrade"
echo "tarball=$TARBALL_PATH"
echo "current_version=${CURRENT_VERSION_VALUE:-unknown}"
echo "target_version=${TARGET_VERSION_VALUE:-unknown}"
echo "manifest=$MANIFEST_FILE"
echo "config_snapshot=$CONFIG_SNAPSHOT"
if [[ -n "$ROLLBACK_TARBALL_PATH" ]]; then
  echo "rollback_artifact=$ROLLBACK_TARBALL_PATH"
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  MANIFEST_STATUS="dry_run"
  echo "dry-run ok"
  exit 0
fi

[[ -x "$EXTRACTED_TREE_PATH/install.sh" ]] || {
  MANIFEST_STATUS="failed"
  echo "ERROR: extracted release tree missing install.sh" >&2
  exit 1
}

set +e
(
  cd "$EXTRACTED_TREE_PATH"
  LM_INSTALL_SKIP_ROOT_CHECK="${LM_INSTALL_SKIP_ROOT_CHECK:-$([[ "${LM_UPGRADE_SKIP_ROOT_CHECK:-0}" =~ ^(1|true|TRUE|yes|YES|on|ON)$ ]] && echo 1 || echo 0)}" \
  LM_INSTALL_CFG_DIR="$CFG_DIR" \
  LM_INSTALL_LOG_DIR="$LOG_DIR" \
  LM_INSTALL_STATE_DIR="$STATE_DIR" \
  LM_INSTALL_SYSTEMD_DIR="$INSTALL_SYSTEMD_DIR" \
  LM_INSTALL_LOGROTATE_FILE="$INSTALL_LOGROTATE_FILE" \
  bash ./install.sh "${install_flags[@]}"
)
INSTALL_RC_VALUE=$?
set -e
if [[ "$INSTALL_RC_VALUE" -ne 0 ]]; then
  MANIFEST_STATUS="failed"
  echo "ERROR: install.sh failed during upgrade (rc=$INSTALL_RC_VALUE)" >&2
  exit "$INSTALL_RC_VALUE"
fi

set +e
verify_install_env=(env PREFIX="$PREFIX" LM_CFG_DIR="$CFG_DIR" LOG_DIR="$LOG_DIR" LM_STATE_DIR="$STATE_DIR")
if [[ -n "$INSTALL_SYSTEMD_DIR" ]]; then
  verify_install_env+=(LM_SYSTEMD_UNIT_DIRS="$INSTALL_SYSTEMD_DIR")
fi
if [[ -n "${LM_LOCKDIR:-}" ]]; then
  verify_install_env+=(LM_LOCKDIR="$LM_LOCKDIR")
fi
"${verify_install_env[@]}" "$PREFIX/bin/linux-maint" verify-install >/dev/null
VERIFY_INSTALL_RC_VALUE=$?
set -e
if [[ "$VERIFY_INSTALL_RC_VALUE" -ne 0 ]]; then
  MANIFEST_STATUS="failed"
  echo "ERROR: post-upgrade verify-install failed (rc=$VERIFY_INSTALL_RC_VALUE)" >&2
  exit "$VERIFY_INSTALL_RC_VALUE"
fi

MANIFEST_STATUS="success"
echo "upgrade ok"
echo "upgrade manifest: $MANIFEST_FILE"
