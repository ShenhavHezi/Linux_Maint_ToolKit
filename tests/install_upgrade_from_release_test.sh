#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CURRENT_VERSION="$(head -n 1 "$ROOT_DIR/VERSION" | tr -d '[:space:]')"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

require_tag(){
  local tag="$1"
  if ! command -v git >/dev/null 2>&1; then
    echo "git is required for install upgrade test" >&2
    exit 1
  fi
  git -C "$ROOT_DIR" rev-parse -q --verify "refs/tags/$tag" >/dev/null || {
    if git -C "$ROOT_DIR" remote get-url origin >/dev/null 2>&1; then
      git -C "$ROOT_DIR" fetch --force --tags origin "refs/tags/$tag:refs/tags/$tag" >/dev/null 2>&1 || true
    fi
  }
  git -C "$ROOT_DIR" rev-parse -q --verify "refs/tags/$tag" >/dev/null || {
    echo "required release tag missing: $tag" >&2
    exit 1
  }
}

export_tag_tree(){
  local tag="$1" dest="$2"
  mkdir -p "$dest"
  git -C "$ROOT_DIR" archive "$tag" | tar -xf - -C "$dest"
}

prepare_legacy_install_tree(){
  local tree="$1"
  if grep -q 'LM_INSTALL_CFG_DIR' "$tree/install.sh"; then
    return 0
  fi
  python3 - "$tree/install.sh" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
text = text.replace(
    'INSTALL_PREFIX="/usr/local"\n',
    'INSTALL_PREFIX="/usr/local"\n'
    'INSTALL_CFG_DIR="${LM_INSTALL_CFG_DIR:-/etc/linux_maint}"\n'
    'INSTALL_LOG_DIR="${LM_INSTALL_LOG_DIR:-/var/log/health}"\n'
    'INSTALL_STATE_DIR="${LM_INSTALL_STATE_DIR:-/var/lib/linux_maint}"\n'
    'INSTALL_SKIP_ROOT_CHECK="${LM_INSTALL_SKIP_ROOT_CHECK:-0}"\n',
    1,
)
text = text.replace(
    '''need_root(){
  if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    echo "ERROR: must run as root" >&2
    exit 1
  fi
}
''',
    '''need_root(){
  case "$INSTALL_SKIP_ROOT_CHECK" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
  esac
  if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    echo "ERROR: must run as root" >&2
    exit 1
  fi
}
''',
    1,
)
text = text.replace(
    '    chown root:root /etc/linux_maint/linux-maint.conf || true\n',
    '    if [ "${EUID:-$(id -u)}" -eq 0 ]; then\n      chown root:root /etc/linux_maint/linux-maint.conf || true\n    fi\n',
    1,
)
text = text.replace('  chown -R root:root "$libexec"\n', '  if [ "${EUID:-$(id -u)}" -eq 0 ]; then\n    chown -R root:root "$libexec"\n  fi\n', 1)
for src, dest in (
    ("/etc/linux_maint", '${INSTALL_CFG_DIR}'),
    ("/var/log/health", '${INSTALL_LOG_DIR}'),
    ("/var/lib/linux_maint", '${INSTALL_STATE_DIR}'),
):
    text = text.replace(src, dest)
path.write_text(text, encoding="utf-8")
PY
}

install_from_tree(){
  local tree="$1" prefix="$2" cfg="$3" logdir="$4" statedir="$5"
  (
    cd "$tree"
    LM_INSTALL_SKIP_ROOT_CHECK=1 \
    LM_INSTALL_CFG_DIR="$cfg" \
    LM_INSTALL_LOG_DIR="$logdir" \
    LM_INSTALL_STATE_DIR="$statedir" \
    bash ./install.sh --prefix "$prefix" >/dev/null
  )
}

install_current(){
  local prefix="$1" cfg="$2" logdir="$3" statedir="$4"
  (
    cd "$ROOT_DIR"
    LM_INSTALL_SKIP_ROOT_CHECK=1 \
    LM_INSTALL_CFG_DIR="$cfg" \
    LM_INSTALL_LOG_DIR="$logdir" \
    LM_INSTALL_STATE_DIR="$statedir" \
    bash ./install.sh --prefix "$prefix" >/dev/null
  )
}

install_current_fail(){
  local prefix="$1" cfg="$2" logdir="$3" statedir="$4"
  (
    cd "$ROOT_DIR"
    LM_INSTALL_SKIP_ROOT_CHECK=1 \
    LM_INSTALL_CFG_DIR="$cfg" \
    LM_INSTALL_LOG_DIR="$logdir" \
    LM_INSTALL_STATE_DIR="$statedir" \
    LM_INSTALL_FAIL_AT=after_payload_install \
    bash ./install.sh --prefix "$prefix"
  )
}

uninstall_current(){
  local prefix="$1" cfg="$2" logdir="$3" statedir="$4"
  (
    cd "$ROOT_DIR"
    LM_INSTALL_SKIP_ROOT_CHECK=1 \
    LM_INSTALL_CFG_DIR="$cfg" \
    LM_INSTALL_LOG_DIR="$logdir" \
    LM_INSTALL_STATE_DIR="$statedir" \
    bash ./install.sh --prefix "$prefix" --uninstall >/dev/null
  )
}

sha_file(){
  sha256sum "$1" | awk '{print $1}'
}

run_success_case(){
  local tag="$1"
  local case_root="$workdir/${tag}_success"
  local old_tree="$case_root/old_tree"
  local prefix="$case_root/prefix"
  local cfg="$case_root/etc_linux_maint"
  local logdir="$case_root/var_log_health"
  local statedir="$case_root/var_lib_linux_maint"
  local current_bin_sum current_help

  export_tag_tree "$tag" "$old_tree"
  prepare_legacy_install_tree "$old_tree"
  install_from_tree "$old_tree" "$prefix" "$cfg" "$logdir" "$statedir"

  printf '# keep=%s\n' "$tag" >> "$cfg/linux-maint.conf"
  printf 'marker=%s\n' "$tag" > "$cfg/conf.d/site.conf"

  install_current "$prefix" "$cfg" "$logdir" "$statedir"

  [[ -x "$prefix/bin/linux-maint" ]] || {
    echo "linux-maint missing after upgrade from $tag" >&2
    exit 1
  }

  [[ "$(head -n 1 "$prefix/share/linux_maint/VERSION" | tr -d '[:space:]')" == "$CURRENT_VERSION" ]] || {
    echo "installed VERSION not updated after upgrade from $tag" >&2
    exit 1
  }

  grep -q "^# keep=$tag$" "$cfg/linux-maint.conf" || {
    echo "linux-maint.conf not preserved during upgrade from $tag" >&2
    exit 1
  }

  grep -q "^marker=$tag$" "$cfg/conf.d/site.conf" || {
    echo "conf.d override not preserved during upgrade from $tag" >&2
    exit 1
  }

  current_bin_sum="$(sha_file "$ROOT_DIR/bin/linux-maint")"
  [[ "$(sha_file "$prefix/bin/linux-maint")" == "$current_bin_sum" ]] || {
    echo "installed linux-maint does not match current tree after upgrade from $tag" >&2
    exit 1
  }

  current_help="$(NO_COLOR=1 "$prefix/bin/linux-maint" help status 2>&1 || true)"
  printf '%s\n' "$current_help" | grep -q '^Purpose:$' || {
    echo "installed help status missing structured output after upgrade from $tag" >&2
    echo "$current_help" >&2
    exit 1
  }

  uninstall_current "$prefix" "$cfg" "$logdir" "$statedir"

  [[ ! -e "$prefix/bin/linux-maint" ]] || {
    echo "linux-maint still present after uninstall following upgrade from $tag" >&2
    exit 1
  }
}

run_rollback_case(){
  local tag="$1"
  local case_root="$workdir/${tag}_rollback"
  local old_tree="$case_root/old_tree"
  local prefix="$case_root/prefix"
  local cfg="$case_root/etc_linux_maint"
  local logdir="$case_root/var_log_health"
  local statedir="$case_root/var_lib_linux_maint"
  local old_bin="$case_root/old_linux_maint"
  local had_old_version=0 old_version="" out rc

  export_tag_tree "$tag" "$old_tree"
  prepare_legacy_install_tree "$old_tree"
  install_from_tree "$old_tree" "$prefix" "$cfg" "$logdir" "$statedir"
  cp -a "$prefix/bin/linux-maint" "$old_bin"
  if [[ -f "$prefix/share/linux_maint/VERSION" ]]; then
    had_old_version=1
    old_version="$(head -n 1 "$prefix/share/linux_maint/VERSION" | tr -d '[:space:]')"
  fi
  printf 'rollback=%s\n' "$tag" > "$cfg/conf.d/rollback.conf"

  set +e
  out="$(install_current_fail "$prefix" "$cfg" "$logdir" "$statedir" 2>&1)"
  rc=$?
  set -e

  [[ "$rc" -ne 0 ]] || {
    echo "expected upgrade rollback path to fail for $tag" >&2
    exit 1
  }

  grep -q '^Install failed; restoring previous payloads$' <<< "$out" || {
    echo "rollback message missing for failed upgrade from $tag" >&2
    echo "$out" >&2
    exit 1
  }

  cmp -s "$old_bin" "$prefix/bin/linux-maint" || {
    echo "linux-maint binary not restored after failed upgrade from $tag" >&2
    exit 1
  }

  if [[ "$had_old_version" -eq 1 ]]; then
    [[ "$(head -n 1 "$prefix/share/linux_maint/VERSION" | tr -d '[:space:]')" == "$old_version" ]] || {
      echo "VERSION file not restored after failed upgrade from $tag" >&2
      exit 1
    }
  else
    [[ ! -e "$prefix/share/linux_maint/VERSION" ]] || {
      echo "VERSION file unexpectedly created after failed upgrade from $tag" >&2
      exit 1
    }
  fi

  grep -q "^rollback=$tag$" "$cfg/conf.d/rollback.conf" || {
    echo "config state not preserved after failed upgrade from $tag" >&2
    exit 1
  }
}

for tag in v0.3.2 v0.3.3; do
  require_tag "$tag"
  run_success_case "$tag"
  run_rollback_case "$tag"
done

echo "install upgrade from release ok"
