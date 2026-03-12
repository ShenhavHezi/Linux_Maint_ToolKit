#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

source "$LM" >/dev/null 2>&1

# Repo mode: should resolve to repo docs when present.
repo_doc="$(find_doc_file QUICK_REFERENCE.md)"
[[ "$repo_doc" == "$ROOT_DIR/docs/QUICK_REFERENCE.md" ]] || {
  echo "repo docs resolution failed: $repo_doc" >&2
  exit 1
}

tmp="$(mktemp -d)"
cleanup() { rm -rf "$tmp"; }
trap cleanup EXIT

# Installed mode fallback path.
PREFIX="$tmp/prefix"
SHARE="$tmp/share/linux_maint"
REPO_ROOT="$tmp/no-repo"
mkdir -p "$PREFIX/share/Linux_Maint_ToolKit/docs"
touch "$PREFIX/share/Linux_Maint_ToolKit/docs/FAQ.md"

inst_doc="$(find_doc_file FAQ.md)"
[[ "$inst_doc" == "$PREFIX/share/Linux_Maint_ToolKit/docs/FAQ.md" ]] || {
  echo "installed docs resolution failed: $inst_doc" >&2
  exit 1
}

echo "menu doc path resolution ok"
