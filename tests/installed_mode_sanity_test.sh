#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PREFIX="/usr/local"

if ! sudo -n true >/dev/null 2>&1; then
  echo "SKIP: sudo required for installed-mode sanity check" >&2
  exit 0
fi

# Ensure an installed layout exists (idempotent).
sudo "$ROOT_DIR/install.sh" --prefix "$PREFIX" >/dev/null

fail=0

check_file() {
  local label="$1" path="$2"
  if [[ -e "$path" ]]; then
    echo "OK: $label: $path"
  else
    echo "MISSING: $label: $path" >&2
    fail=1
  fi
}

check_exec() {
  local label="$1" path="$2"
  if [[ -x "$path" ]]; then
    echo "OK: $label: $path"
  elif [[ -e "$path" ]]; then
    echo "NOT EXECUTABLE: $label: $path" >&2
    fail=1
  else
    echo "MISSING: $label: $path" >&2
    fail=1
  fi
}

check_dir() {
  local label="$1" path="$2"
  if [[ -d "$path" ]]; then
    echo "OK: $label: $path"
  else
    echo "MISSING: $label: $path" >&2
    fail=1
  fi
}

check_writable_dir() {
  local label="$1" path="$2"
  if [[ -d "$path" ]]; then
    local probe
    probe="$path/.linux_maint_write_test"
    if sudo bash -c ": > '$probe'" 2>/dev/null; then
      sudo rm -f "$probe" 2>/dev/null || true
      echo "OK: writable $label: $path"
    else
      echo "NOT WRITABLE: $label: $path" >&2
      fail=1
    fi
  else
    echo "MISSING: $label: $path" >&2
    fail=1
  fi
}

check_exec "linux-maint" "$PREFIX/bin/linux-maint"
check_exec "wrapper" "$PREFIX/sbin/run_full_health_monitor.sh"
check_file "library" "$PREFIX/lib/linux_maint.sh"
check_dir "libexec" "$PREFIX/libexec/linux_maint"

shopt -s nullglob
monitors=("$PREFIX/libexec/linux_maint"/*.sh)
shopt -u nullglob
if [[ ${#monitors[@]} -eq 0 ]]; then
  echo "MISSING: monitor scripts in $PREFIX/libexec/linux_maint" >&2
  fail=1
fi

check_file "docs/REASONS.md" "$PREFIX/share/Linux_Maint_ToolKit/docs/REASONS.md"
check_file "templates" "$PREFIX/share/linux_maint/templates/linux_maint/linux-maint.conf.example"

check_dir "config dir" "/etc/linux_maint"
check_dir "config.d" "/etc/linux_maint/conf.d"
check_file "linux-maint.conf" "/etc/linux_maint/linux-maint.conf"

check_writable_dir "logs" "/var/log/health"
check_writable_dir "state" "/var/lib/linux_maint"

sudo "$PREFIX/bin/linux-maint" version >/dev/null 2>&1 || true

if [[ "$fail" -ne 0 ]]; then
  echo "installed-mode sanity FAIL" >&2
  exit 1
fi

echo "installed-mode sanity ok"
