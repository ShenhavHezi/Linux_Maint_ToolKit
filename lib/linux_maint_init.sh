#!/usr/bin/env bash
# Init command helpers for linux-maint.

linux_maint_cmd_init() {
  local INIT_MINIMAL=0 INIT_FORCE=0 CFG_DIR SRC_DIR ALT base dest existed
  local -a init_runner=() init_templates=()

  if [[ "$MODE" == "installed" ]]; then
    need_root_for init
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --minimal) INIT_MINIMAL=1; shift ;;
      --force) INIT_FORCE=1; shift ;;
      *) echo "Unknown init flag: $1" >&2; exit 2 ;;
    esac
  done

  CFG_DIR="$(linux_maint_effective_cfg_dir)"

  if [[ "$MODE" == "installed" && "$(id -u)" -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
      init_runner=(sudo)
    else
      echo "ERROR: linux-maint init requires root in installed mode, and sudo is not available." >&2
      exit 1
    fi
  fi

  SRC_DIR="$REPO_ROOT/etc/linux_maint"
  if [[ "$MODE" == "installed" ]]; then
    ALT="$SHARE/templates/linux_maint"
    [[ -d "$ALT" ]] && SRC_DIR="$ALT"
  fi
  if [[ -z "$SRC_DIR" || ! -d "$SRC_DIR" ]]; then
    echo "ERROR: templates not found at $SRC_DIR" >&2
    echo "Run init from a git checkout:" >&2
    echo "  git clone https://github.com/ShenhavHezi/Linux_Maint_ToolKit.git" >&2
    echo "  cd Linux_Maint_ToolKit" >&2
    echo "  sudo ./bin/linux-maint init" >&2
    exit 1
  fi

  "${init_runner[@]}" mkdir -p "$CFG_DIR"
  if [[ "$INIT_MINIMAL" -eq 0 ]]; then
    "${init_runner[@]}" mkdir -p \
      "$CFG_DIR/baselines" \
      "$CFG_DIR/baselines/ports" \
      "$CFG_DIR/baselines/configs" \
      "$CFG_DIR/baselines/users" \
      "$CFG_DIR/baselines/sudoers"
  fi

  if [[ "$INIT_MINIMAL" -eq 1 ]]; then
    init_templates=(
      "$SRC_DIR/servers.txt.example"
      "$SRC_DIR/excluded.txt.example"
      "$SRC_DIR/services.txt.example"
    )
  else
    shopt -s nullglob
    init_templates=("$SRC_DIR"/*.example)
  fi

  for f in "${init_templates[@]}"; do
    [[ -f "$f" ]] || continue
    base="$(basename "$f" .example)"
    dest="$CFG_DIR/$base"
    existed=0
    [[ -e "$dest" ]] && existed=1
    if [[ "$existed" -eq 1 && "$INIT_FORCE" -eq 0 ]]; then
      echo "keep:   $dest (exists)"
      continue
    fi
    if [[ "${LM_INIT_USE_CP:-0}" == "1" ]]; then
      if [[ "$INIT_FORCE" -eq 1 ]]; then
        "${init_runner[@]}" cp -f "$f" "$dest"
      else
        "${init_runner[@]}" cp "$f" "$dest"
      fi
      "${init_runner[@]}" chmod 0644 "$dest"
    else
      "${init_runner[@]}" install -m 0644 "$f" "$dest"
    fi
    if [[ "$existed" -eq 1 && "$INIT_FORCE" -eq 1 ]]; then
      echo "overwrite: $dest"
    else
      echo "create: $dest"
    fi
  done

  echo ""
  echo "Next steps:"
  echo "  - Edit $CFG_DIR/servers.txt"
  if [[ "$MODE" == "installed" ]]; then
    echo "  - Run: sudo linux-maint doctor"
  else
    echo "  - Run: linux-maint doctor"
  fi
  if [[ "$INIT_MINIMAL" -eq 1 ]]; then
    if [[ "$MODE" == "installed" ]]; then
      echo "  - Optional later: run 'sudo linux-maint init' to install full optional templates"
    else
      echo "  - Optional later: run 'linux-maint init' to install full optional templates"
    fi
  fi
}
