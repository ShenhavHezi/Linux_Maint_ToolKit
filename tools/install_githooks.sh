#!/usr/bin/env bash
# tools/install_githooks.sh - Install repo git hooks from .githooks/
#
# Idempotent: safe to run multiple times.
# Strategy:
# - For each executable file in .githooks/, install it into .git/hooks/<name>
# - Existing different hook is backed up once to <name>.bak (if not already backed up)
# - If destination already matches, do nothing.

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
GITHOOKS_DIR="$ROOT_DIR/.githooks"
GIT_DIR="$ROOT_DIR/.git"
DEST_DIR="$GIT_DIR/hooks"

if [ ! -d "$GIT_DIR" ]; then
  echo "ERROR: not a git repository: $GIT_DIR" >&2
  exit 1
fi

if [ ! -d "$GITHOOKS_DIR" ]; then
  echo "ERROR: missing hooks source dir: $GITHOOKS_DIR" >&2
  exit 1
fi

mkdir -p "$DEST_DIR"

installed=0
skipped=0

# Only install executable regular files
shopt -s nullglob
for src in "$GITHOOKS_DIR"/*; do
  [ -f "$src" ] || continue
  [ -x "$src" ] || continue

  name="$(basename "$src")"
  dest="$DEST_DIR/$name"

  if [ -f "$dest" ]; then
    # If already identical, skip
    if cmp -s "$src" "$dest"; then
      skipped=$((skipped+1))
      continue
    fi

    # Backup once
    if [ ! -f "$dest.bak" ]; then
      cp -p "$dest" "$dest.bak"
      echo "Backed up existing hook: $dest -> $dest.bak"
    fi
  fi

  cp -p "$src" "$dest"
  chmod +x "$dest" || true
  echo "Installed hook: $name"
  installed=$((installed+1))

done

echo "Done. installed=$installed skipped=$skipped"
