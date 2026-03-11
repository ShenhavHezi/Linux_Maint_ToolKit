#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

prefix="$workdir/prefix"
cfg_dir="$workdir/etc_linux_maint"
shim="$workdir/shim"
fake_lm="$prefix/bin/linux-maint"

mkdir -p "$prefix/bin" "$prefix/lib" "$prefix/share/linux_maint/templates" "$cfg_dir" "$shim"

cp "$ROOT_DIR/bin/linux-maint" "$fake_lm"
chmod +x "$fake_lm"
for support_lib in linux_maint.sh linux_maint_runtime.sh linux_maint_admin.sh linux_maint_help.sh; do
  cp "$ROOT_DIR/lib/$support_lib" "$prefix/lib/$support_lib"
done
cp -a "$ROOT_DIR/etc/linux_maint" "$prefix/share/linux_maint/templates/"

perl -0pi -e 's/if \[\[ "\$MODE" == "installed" \]\]; then\n      need_root_for init\n    fi/if [[ "$MODE" == "installed" ]]; then\n      :\n    fi/' "$fake_lm"

cat > "$shim/id" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "-u" ]]; then
  printf '0\n'
  exit 0
fi
exec /usr/bin/id "$@"
SH
chmod +x "$shim/id"

cat > "$shim/sudo" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
echo "sudo should not be called for installed-mode init when already root" >&2
exit 99
SH
chmod +x "$shim/sudo"

PATH="$shim:/usr/bin:/bin" PREFIX="$prefix" LM_CFG_DIR="$cfg_dir" LM_INIT_USE_CP=1 \
  bash "$fake_lm" init --minimal >/dev/null

for required in servers.txt excluded.txt services.txt; do
  [[ -f "$cfg_dir/$required" ]] || {
    echo "installed-mode init did not create $required without sudo when already root" >&2
    exit 1
  }
done

echo "init installed root no sudo ok"
