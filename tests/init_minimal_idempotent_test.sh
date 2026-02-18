#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

cfg_dir="$workdir/etc_linux_maint"
shim="$workdir/shim"
mkdir -p "$cfg_dir" "$shim"

# Shim sudo for non-root CI: pass through command.
cat > "$shim/sudo" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
exec "$@"
SH
chmod +x "$shim/sudo"

run_init_minimal(){
  PATH="$shim:$PATH" \
  LM_CFG_DIR="$cfg_dir" \
  LM_INIT_USE_CP=1 \
  "$ROOT_DIR/bin/linux-maint" init --minimal >/dev/null
}

run_init_minimal
run_init_minimal

# Required minimal files should exist
[ -f "$cfg_dir/servers.txt" ]
[ -f "$cfg_dir/excluded.txt" ]
[ -f "$cfg_dir/services.txt" ]

# Optional templates should not be created in minimal mode
[ ! -f "$cfg_dir/network_targets.txt" ]
[ ! -f "$cfg_dir/certs.txt" ]
[ ! -d "$cfg_dir/baselines" ]

echo "init minimal idempotent ok"
