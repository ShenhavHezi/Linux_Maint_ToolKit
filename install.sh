#!/usr/bin/env bash
# install.sh - Installer for Linux_Maint_Scripts (recommended Linux paths)
#
# Installs:
# - wrapper: /usr/local/sbin/run_full_health_monitor.sh
# - library: /usr/local/lib/linux_maint.sh
# - monitors: /usr/local/libexec/linux_maint/*.sh (explicit list)
#
# Optional:
# - create linuxmaint user
# - create systemd service/timer
# - install logrotate config
#
# Usage examples:
#   sudo ./install.sh
#   sudo ./install.sh --with-user --with-timer --with-logrotate
#   sudo ./install.sh --uninstall

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_LIBS_FILE="$SCRIPT_DIR/lib/RELEASE_LIBS.txt"

WITH_USER=false
WITH_TIMER=false
WITH_LOGROTATE=false
UNINSTALL=false
PURGE=false
USER_NAME="linuxmaint"
INSTALL_PREFIX="/usr/local"
INSTALL_CFG_DIR="${LM_INSTALL_CFG_DIR:-/etc/linux_maint}"
INSTALL_LOG_DIR="${LM_INSTALL_LOG_DIR:-/var/log/health}"
INSTALL_STATE_DIR="${LM_INSTALL_STATE_DIR:-/var/lib/linux_maint}"
INSTALL_SYSTEMD_DIR="${LM_INSTALL_SYSTEMD_DIR:-/etc/systemd/system}"
INSTALL_LOGROTATE_FILE="${LM_INSTALL_LOGROTATE_FILE:-/etc/logrotate.d/linux_maint}"
INSTALL_SKIP_ROOT_CHECK="${LM_INSTALL_SKIP_ROOT_CHECK:-0}"
INSTALL_FAIL_AT="${LM_INSTALL_FAIL_AT:-}"
ROLLBACK_DIR=""
ROLLBACK_ACTIVE=0
ROLLBACK_TOUCH_SYSTEMD=0
ROLLBACK_TOUCH_LOGROTATE=0

usage(){
  cat <<EOF
Usage: sudo $0 [options]

Options:
  --with-user            Create dedicated user (${USER_NAME}) if missing
  --with-timer           Install and enable systemd service+timer (daily)
  --with-logrotate       Install /etc/logrotate.d/linux_maint
  --user NAME            Set username (default: ${USER_NAME})
  --prefix PATH          Install prefix (default: ${INSTALL_PREFIX})
  --uninstall            Remove installed files (keeps /etc/linux_maint and logs)
  --purge                With --uninstall: also remove systemd units + logrotate + optional dirs
  -h, --help             Show help
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --with-user) WITH_USER=true; shift;;
    --with-timer) WITH_TIMER=true; shift;;
    --with-logrotate) WITH_LOGROTATE=true; shift;;
    --uninstall) UNINSTALL=true; shift;;
    --purge) PURGE=true; shift;;
    --user) USER_NAME="$2"; shift 2;;
    --prefix) INSTALL_PREFIX="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown option: $1"; usage; exit 2;;
  esac
done

need_root(){
  case "$INSTALL_SKIP_ROOT_CHECK" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
  esac
  if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    echo "ERROR: must run as root" >&2
    exit 1
  fi
}

maybe_fail_install_stage(){
  local stage="${1:-}"
  if [[ -n "$INSTALL_FAIL_AT" && "$INSTALL_FAIL_AT" == "$stage" ]]; then
    echo "ERROR: install failpoint triggered at stage=$stage" >&2
    return 99
  fi
}

read_release_libs() {
  [[ -f "$RELEASE_LIBS_FILE" ]] || {
    echo "ERROR: release lib manifest not found: $RELEASE_LIBS_FILE" >&2
    exit 1
  }
  cat "$RELEASE_LIBS_FILE"
}

install_payload_paths(){
  cat <<'EOF'
bin/linux-maint
sbin/run_full_health_monitor.sh
lib/RELEASE_LIBS.txt
libexec/linux_maint
share/linux_maint
share/Linux_Maint_ToolKit
EOF
  while IFS= read -r lib_name; do
    printf 'lib/%s\n' "$lib_name"
  done < <(read_release_libs)
}

backup_existing_payloads(){
  local prefix="$1"
  local backup_root="$2"
  local rel src dst
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    src="$prefix/$rel"
    dst="$backup_root/$rel"
    if [[ -e "$src" ]]; then
      mkdir -p "$(dirname "$dst")"
      cp -a "$src" "$dst"
    fi
  done < <(install_payload_paths)
}

cleanup_prefix_payloads(){
  local prefix="$1"
  local rel
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    rm -rf "${prefix:?}/$rel"
  done < <(install_payload_paths)
}

restore_existing_payloads(){
  local prefix="$1"
  local backup_root="$2"
  local rel src dst
  cleanup_prefix_payloads "$prefix"
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    src="$backup_root/$rel"
    dst="$prefix/$rel"
    if [[ -e "$src" ]]; then
      mkdir -p "$(dirname "$dst")"
      cp -a "$src" "$dst"
    fi
  done < <(install_payload_paths)
}

backup_system_artifacts(){
  local backup_root="$1"
  local entry src dst
  for entry in \
    "service:$INSTALL_SYSTEMD_DIR/linux-maint.service" \
    "timer:$INSTALL_SYSTEMD_DIR/linux-maint.timer" \
    "logrotate:$INSTALL_LOGROTATE_FILE"
  do
    src="${entry#*:}"
    dst="$backup_root/${entry%%:*}"
    if [[ -e "$src" ]]; then
      mkdir -p "$(dirname "$dst")"
      cp -a "$src" "$dst"
    fi
  done
}

restore_system_artifacts(){
  local backup_root="$1"
  local service_path="$INSTALL_SYSTEMD_DIR/linux-maint.service"
  local timer_path="$INSTALL_SYSTEMD_DIR/linux-maint.timer"
  local entry src dst

  if [[ "$ROLLBACK_TOUCH_SYSTEMD" -eq 1 || -e "$backup_root/service" || -e "$backup_root/timer" ]]; then
    rm -f "$service_path" "$timer_path"
  fi
  if [[ "$ROLLBACK_TOUCH_LOGROTATE" -eq 1 || -e "$backup_root/logrotate" ]]; then
    rm -f "$INSTALL_LOGROTATE_FILE"
  fi
  for entry in \
    "service:$service_path" \
    "timer:$timer_path" \
    "logrotate:$INSTALL_LOGROTATE_FILE"
  do
    src="$backup_root/${entry%%:*}"
    dst="${entry#*:}"
    if [[ -e "$src" ]]; then
      mkdir -p "$(dirname "$dst")"
      cp -a "$src" "$dst"
    fi
  done

  if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload >/dev/null 2>&1 || true
  fi
}

install_cleanup(){
  local rc=$?
  trap - EXIT
  if [[ "$ROLLBACK_ACTIVE" -eq 1 ]]; then
    echo "Install failed; restoring previous payloads" >&2
    restore_existing_payloads "$INSTALL_PREFIX" "$ROLLBACK_DIR/prefix"
    restore_system_artifacts "$ROLLBACK_DIR/system"
  fi
  if [[ -n "$ROLLBACK_DIR" && -d "$ROLLBACK_DIR" ]]; then
    rm -rf "$ROLLBACK_DIR" 2>/dev/null || true
  fi
  exit "$rc"
}

prepare_install_rollback(){
  ROLLBACK_DIR="$(mktemp -d -p "${TMPDIR:-/tmp}" linux_maint_install_rollback.XXXXXX)"
  mkdir -p "$ROLLBACK_DIR/prefix" "$ROLLBACK_DIR/system"
  backup_existing_payloads "$INSTALL_PREFIX" "$ROLLBACK_DIR/prefix"
  backup_system_artifacts "$ROLLBACK_DIR/system"
  ROLLBACK_ACTIVE=1
  trap install_cleanup EXIT
}

finalize_install_rollback(){
  ROLLBACK_ACTIVE=0
  trap - EXIT
  if [[ -n "$ROLLBACK_DIR" && -d "$ROLLBACK_DIR" ]]; then
    rm -rf "$ROLLBACK_DIR" 2>/dev/null || true
  fi
  ROLLBACK_DIR=""
}

create_user(){
  local u="$1"
  if id "$u" >/dev/null 2>&1; then
    echo "User $u already exists"
    return 0
  fi
  echo "Creating user $u"
  useradd -r -m -s /bin/bash "$u"
}

install_files(){
  local prefix="$1"
  local sbin="$prefix/sbin"
  local lib="$prefix/lib"
  local libexec="$prefix/libexec/linux_maint"

  echo "Installing to:"
  echo "  wrapper:  $sbin/run_full_health_monitor.sh"
  echo "  library:  $lib/linux_maint.sh"
  echo "  monitors: $libexec/"

  while IFS= read -r lib_name; do
    install -D -m 0755 "lib/$lib_name" "$lib/$lib_name"
  done < <(read_release_libs)
  install -D -m 0644 "$RELEASE_LIBS_FILE" "$lib/RELEASE_LIBS.txt"
  install -D -m 0755 run_full_health_monitor.sh "$sbin/run_full_health_monitor.sh"
  install -D -m 0755 bin/linux-maint "$prefix/bin/linux-maint"
  install -d "$libexec"

  # tools used by the CLI (installed-mode)
  install -D -m 0755 tools/summary_diff.py "$libexec/summary_diff.py"
  install -D -m 0755 tools/pack_logs.sh "$libexec/pack_logs.sh"
  install -D -m 0755 tools/seed_known_hosts.sh "$libexec/seed_known_hosts.sh"
  install -D -m 0755 tools/upgrade_release.sh "$libexec/upgrade_release.sh"
  install -D -m 0755 tools/verify_release.sh "$libexec/verify_release.sh"

  # Install all monitor scripts (keeps packaging in sync with repo changes).
  install -D -m 0755 monitors/*.sh "$libexec/"

  # Hardening
  if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    chown -R root:root "$libexec"
  fi
  chmod -R go-w "$libexec"

  # Directories
  mkdir -p "$INSTALL_CFG_DIR" "$INSTALL_CFG_DIR/baselines" "$INSTALL_LOG_DIR" "$INSTALL_STATE_DIR"

  # main config (do not overwrite if exists)
  if [ ! -f "$INSTALL_CFG_DIR/linux-maint.conf" ]; then
    install -m 0640 etc/linux_maint/linux-maint.conf.example "$INSTALL_CFG_DIR/linux-maint.conf"
    if [ "${EUID:-$(id -u)}" -eq 0 ]; then
      chown root:root "$INSTALL_CFG_DIR/linux-maint.conf"
    fi
  fi
  mkdir -p "$INSTALL_CFG_DIR/conf.d"
  chmod 0755 "$INSTALL_CFG_DIR/conf.d" || true

  # Build/version info (optional; present in offline release tarballs)
  # Ensure BUILD_INFO exists for installed-mode `linux-maint version`
  if [ ! -f "BUILD_INFO" ] && [ -x "tools/gen_build_info.sh" ]; then
    ./tools/gen_build_info.sh >/dev/null 2>&1 || true
  fi
  mkdir -p "$prefix/share/linux_maint"
  mkdir -p "$prefix/share/linux_maint/plugins"
  # Operator docs (useful for dark-site installs).
  # Keep under share so installed-mode commands (e.g. `linux-maint explain`) can find them.
  mkdir -p "$prefix/share/Linux_Maint_ToolKit/docs"
  if [ -d "docs" ]; then
    cp -a docs/*.md "$prefix/share/Linux_Maint_ToolKit/docs/" 2>/dev/null || true
  fi
  # config templates for linux-maint init (installed-mode)
  mkdir -p "$prefix/share/linux_maint/templates"
  cp -a etc/linux_maint "$prefix/share/linux_maint/templates/"
  if [ -f "VERSION" ]; then
    install -m 0644 VERSION "$prefix/share/linux_maint/VERSION"
  fi
  if [ -f "plugins/index.json" ]; then
    install -m 0644 plugins/index.json "$prefix/share/linux_maint/plugins/index.json"
  fi
  if [ -f "BUILD_INFO" ]; then
    install -m 0644 BUILD_INFO "$prefix/share/linux_maint/BUILD_INFO"
  fi

  maybe_fail_install_stage "after_payload_install"

  echo "Install complete. Try: $sbin/run_full_health_monitor.sh"
}

install_logrotate(){
  local log_dir_escaped="${INSTALL_LOG_DIR%/}"
  ROLLBACK_TOUCH_LOGROTATE=1
  echo "Installing logrotate config to $INSTALL_LOGROTATE_FILE"
  mkdir -p "$(dirname "$INSTALL_LOGROTATE_FILE")"
  cat > "$INSTALL_LOGROTATE_FILE" <<EOF
/var/log/*monitor*.log /var/log/*_monitor.log /var/log/*_check.log /var/log/inventory_export.log {
  daily
  rotate 14
  missingok
  notifempty
  compress
  delaycompress
  copytruncate
}

${log_dir_escaped}/*.log ${log_dir_escaped}/*.json {
  daily
  rotate 14
  missingok
  notifempty
  compress
  delaycompress
  # These logs are written as one-shot files (not long-lived daemons), so copytruncate is unnecessary.
  # Exclude latest symlinks so they keep pointing at the newest run artifact.
  prerotate
    # Ensure we never create rotated copies of the latest symlinks
    rm -f ${log_dir_escaped}/*_latest.log.* ${log_dir_escaped}/*_latest.json.* 2>/dev/null || true
  endscript
}

# Do not rotate the latest symlinks (rotate=0 effectively ignores them).
${log_dir_escaped}/*_latest.log ${log_dir_escaped}/*_latest.json {
  missingok
  notifempty
  rotate 0
}
EOF
  maybe_fail_install_stage "after_logrotate_write"
}

install_systemd(){
  ROLLBACK_TOUCH_SYSTEMD=1
  echo "Installing systemd unit + timer"
  mkdir -p "$INSTALL_SYSTEMD_DIR"

  cat > "$INSTALL_SYSTEMD_DIR/linux-maint.service" <<EOF
[Unit]
Description=Linux maintenance full health monitor

[Service]
Type=oneshot
ExecStart=${INSTALL_PREFIX}/sbin/run_full_health_monitor.sh
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
LockPersonality=true
MemoryDenyWriteExecute=true
RestrictSUIDSGID=true
SystemCallArchitectures=native
ReadWritePaths=/var/log ${INSTALL_LOG_DIR} ${INSTALL_STATE_DIR} /var/lock /tmp
EOF

  cat > "$INSTALL_SYSTEMD_DIR/linux-maint.timer" <<'EOF'
[Unit]
Description=Run Linux maintenance health checks daily

[Timer]
OnCalendar=*-*-* 02:15:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

  maybe_fail_install_stage "after_systemd_write"

  run_systemctl_best_effort() {
    local timeout_secs=15
    if command -v timeout >/dev/null 2>&1; then
      timeout "$timeout_secs" systemctl "$@" >/dev/null 2>&1
    else
      systemctl "$@" >/dev/null 2>&1
    fi
  }

  if command -v systemctl >/dev/null 2>&1; then
    run_systemctl_best_effort daemon-reload || echo "WARN: systemctl daemon-reload failed" >&2
    run_systemctl_best_effort enable --now linux-maint.timer || echo "WARN: unable to enable/start linux-maint.timer" >&2
    run_systemctl_best_effort status linux-maint.timer --no-pager || true
  else
    echo "INFO: systemctl not found; installed unit files only" >&2
  fi
}

uninstall_files(){
  local prefix="$1"
  echo "Uninstalling from prefix: $prefix"
  rm -f "$prefix/bin/linux-maint"
  rm -f "$prefix/sbin/run_full_health_monitor.sh"
  while IFS= read -r lib_name; do
    rm -f "$prefix/lib/$lib_name"
  done < <(read_release_libs)
  rm -rf "$prefix/libexec/linux_maint"
  rm -rf "$prefix/share/linux_maint" 2>/dev/null || true
  rm -rf "$prefix/share/Linux_Maint_ToolKit" 2>/dev/null || true
  echo "Uninstall complete. (Kept /etc/linux_maint and /var/log by default.)"
  if $PURGE; then
    echo "Purging systemd units and logrotate (and optional dirs)"
    rm -f "$INSTALL_SYSTEMD_DIR/linux-maint.service" "$INSTALL_SYSTEMD_DIR/linux-maint.timer"
    systemctl daemon-reload >/dev/null 2>&1 || true
    rm -f "$INSTALL_LOGROTATE_FILE"
    rm -rf "$INSTALL_LOG_DIR" || true
    # Uncomment if you want to also remove config/baselines:
    # rm -rf "$INSTALL_CFG_DIR"
  fi
}

need_root

if $UNINSTALL; then
  uninstall_files "$INSTALL_PREFIX"
  exit 0
fi

prepare_install_rollback
$WITH_USER && create_user "$USER_NAME"
install_files "$INSTALL_PREFIX"
$WITH_LOGROTATE && install_logrotate
$WITH_TIMER && install_systemd
finalize_install_rollback

exit 0
