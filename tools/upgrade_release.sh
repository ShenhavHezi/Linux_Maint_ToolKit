#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: linux-maint upgrade <tarball> [flags]

Flags:
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
VERIFY_TOOL="${LINUX_MAINT_UPGRADE_VERIFY_TOOL:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/verify_release.sh}"

while [[ $# -gt 0 ]]; do
  case "$1" in
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

need_root

mkdir -p "$STATE_DIR/upgrades"
run_id="$(date -u +%Y%m%dT%H%M%SZ)-$$"
MANIFEST_DIR="$STATE_DIR/upgrades/$run_id"
mkdir -p "$MANIFEST_DIR"
ln -sfn "$MANIFEST_DIR" "$STATE_DIR/upgrades/latest" 2>/dev/null || true

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

snapshot_config_dir "$CFG_DIR" "$CONFIG_SNAPSHOT"
if [[ ! -f "$CONFIG_SNAPSHOT" && -f "$CONFIG_SNAPSHOT.absent" ]]; then
  CONFIG_SNAPSHOT_PATH="$CONFIG_SNAPSHOT.absent"
fi
write_payload_inventory "$PREFIX" "$PAYLOAD_INVENTORY"
write_rollback_instructions "$ROLLBACK_INSTRUCTIONS" "$ROLLBACK_TARBALL" "$PREFIX"
write_manifest

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
