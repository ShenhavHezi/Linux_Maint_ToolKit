#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: tools/new_monitor.sh <name> [--dest DIR] [--force]

Examples:
  tools/new_monitor.sh my_custom_monitor
  tools/new_monitor.sh disk_audit.sh --dest /tmp
EOF
}

name="${1:-}"
shift || true
dest=""
force=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dest) dest="$2"; shift 2;;
    --force) force=1; shift 1;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown flag: $1" >&2; usage; exit 2;;
  esac
done

if [[ -z "$name" ]]; then
  usage
  exit 2
fi

if [[ -z "$dest" ]]; then
  dest="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/monitors"
fi
mkdir -p "$dest" 2>/dev/null || true

file="$name"
[[ "$file" == *.sh ]] || file="${file}.sh"
path="$dest/$file"
monitor_name="${file%.sh}"

if [[ -f "$path" && "$force" -ne 1 ]]; then
  echo "ERROR: $path already exists (use --force to overwrite)" >&2
  exit 1
fi

cat > "$path" <<EOF
#!/usr/bin/env bash
# ${file} - TODO: short description
# Description:
#   TODO: longer description of what this monitor checks.

set -euo pipefail

for _lm_lib in "\${LINUX_MAINT_LIB:-}" /usr/local/lib/linux_maint.sh /usr/lib/linux_maint.sh; do
  if [[ -n "\$_lm_lib" && -f "\$_lm_lib" ]]; then
    # shellcheck disable=SC1090
    . "\$_lm_lib"
    break
  fi
done
if ! command -v lm_summary >/dev/null 2>&1; then
  echo "Missing linux_maint library (set LINUX_MAINT_LIB or install linux_maint.sh)" >&2
  exit 1
fi
LM_PREFIX="[${monitor_name}] "
LM_LOGFILE="\${LM_LOGFILE:-/var/log/${monitor_name}.log}"

# Optional: config file example (uncomment + customize)
# CONFIG_FILE="\${LM_CFG_DIR:-/etc/linux_maint}/example.txt"

_summary_emitted=0
emit_summary(){ _summary_emitted=1; lm_summary "${monitor_name}" "\$@"; }
trap 'rc=\$?; if [ "\${_summary_emitted:-0}" -eq 0 ]; then lm_summary "${monitor_name}" "localhost" "UNKNOWN" reason=early_exit rc="\$rc"; fi' EXIT

# TODO: implement your checks here.
# Use lm_hosts/lm_ssh for per-host checks, and emit lm_summary per host.

host="localhost"
lm_summary "${monitor_name}" "\$host" "OK"
EOF

chmod +x "$path" 2>/dev/null || true
echo "Created monitor template: $path"
