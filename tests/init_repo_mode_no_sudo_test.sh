#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

cfg_dir="$workdir/etc_linux_maint"
shim="$workdir/shim"
mkdir -p "$cfg_dir" "$shim"

cat > "$shim/sudo" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
echo "sudo should not be called in repo mode" >&2
exit 99
SH
chmod +x "$shim/sudo"

PATH="$shim:$PATH" LM_CFG_DIR="$cfg_dir" LM_INIT_USE_CP=1 "$LM" init --minimal >/dev/null

for required in servers.txt excluded.txt services.txt; do
  [[ -f "$cfg_dir/$required" ]] || {
    echo "init did not create $required in repo mode without sudo" >&2
    exit 1
  }
done

echo "init repo mode no sudo ok"
