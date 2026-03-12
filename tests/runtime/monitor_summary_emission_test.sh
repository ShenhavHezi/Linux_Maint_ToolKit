#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
workdir="$(mktemp -d -p "$TMPDIR" monitor_summary_emission.XXXXXX)"
trap 'rm -rf "$workdir"' EXIT

export LINUX_MAINT_LIB="$ROOT_DIR/lib/linux_maint.sh"
export PATH="$ROOT_DIR/lib:$PATH"
export LM_EMAIL_ENABLED=false
export LM_LOCKDIR="${workdir}"
export LM_LOG_DIR="${workdir}"
export LM_LOGFILE="${workdir}/linux_maint_test.log"
export LM_STATE_DIR="${workdir}/linux_maint_state"
export LM_LOCAL_ONLY=true
export LM_INVENTORY_OUTPUT_DIR="${workdir}/linux_maint_inventory"
# Some monitors need a writable config dir for baselines/allowlists when running unprivileged in CI.
export LM_CFG_DIR="${LM_CFG_DIR:-${workdir}/linux_maint_cfg}"

mkdir -p "$LM_INVENTORY_OUTPUT_DIR" "$LM_STATE_DIR" "$LM_CFG_DIR"

fail=0

for m in "$ROOT_DIR"/monitors/*.sh; do
  name="$(basename "$m" .sh)"
  out_file="${workdir}/${name}_summary_test.out"
  forced_missing_deps=""
  if [[ "$name" == "patch_monitor" ]]; then
    forced_missing_deps="apt-get,dnf,yum,zypper"
  fi

  # Ensure each monitor uses a writable logfile (avoid /var/log permission issues in CI)
  LM_LOGFILE="${workdir}/${name}_summary_test.log" \
  LM_LOG_DIR="${workdir}" \
  LM_STATE_DIR="$LM_STATE_DIR" \
  LM_CFG_DIR="$LM_CFG_DIR" \
  LM_FORCE_MISSING_DEPS="$forced_missing_deps" \
  bash "$m" >"$out_file" 2>/dev/null || true

  summary_count="$(grep -c '^monitor=' "$out_file" || true)"
  if [ "$summary_count" -ne 1 ]; then
    echo "FAIL: $name emitted $summary_count monitor= summary lines (expected exactly 1)" >&2
    echo "--- output (first 50 lines) ---" >&2
    head -n 50 "$out_file" >&2 || true
    echo "--- end output ---" >&2
    fail=1
  fi

  if grep -qv '^monitor=' "$out_file"; then
    echo "FAIL: $name emitted non-summary stdout lines (stdout must be monitor= only)" >&2
    echo "--- output (first 50 lines) ---" >&2
    head -n 50 "$out_file" >&2 || true
    echo "--- end output ---" >&2
    fail=1
  fi

done

[ "$fail" -eq 0 ]

echo "monitor summary emission ok"
