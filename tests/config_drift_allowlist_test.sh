#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
workdir="$(mktemp -d "${TMPDIR:-/tmp}/lm_cfg_drift.XXXXXX")"
cleanup(){ rm -rf "$workdir"; }
trap cleanup EXIT

cfg="$workdir/cfg"
mkdir -p "$cfg/baselines/configs" "$workdir/ignored"

printf '%s\n' localhost > "$cfg/servers.txt"
: > "$cfg/excluded.txt"
printf '%s\n' "$workdir/ignored/target.conf" > "$cfg/config_paths.txt"
printf '%s\n' "$workdir/ignored" > "$cfg/config_allowlist.txt"

printf '%s\n' 'version=1' > "$workdir/ignored/target.conf"
hashbin="$(command -v sha256sum || command -v md5sum)"
algo="$(basename "$hashbin")"
case "$algo" in
  sha256sum) algo_name="sha256" ;;
  md5sum) algo_name="md5" ;;
  *)
    echo "unsupported hash tool: $algo" >&2
    exit 1
    ;;
esac
old_hash="$("$hashbin" "$workdir/ignored/target.conf" | awk '{print $1}')"
abs_path="$(readlink -f "$workdir/ignored/target.conf")"
printf '%s|%s|%s\n' "$algo_name" "$old_hash" "$abs_path" > "$cfg/baselines/configs/localhost.baseline"

printf '%s\n' 'version=2' > "$workdir/ignored/target.conf"

out="$(
  LM_CFG_DIR="$cfg" \
  LM_LOCKDIR="$workdir" \
  LM_LOGFILE="$workdir/config_drift.log" \
  LINUX_MAINT_LIB="$ROOT_DIR/lib/linux_maint.sh" \
  bash "$ROOT_DIR/monitors/config_drift_monitor.sh" 2>/dev/null
)"

printf '%s\n' "$out" | grep -q '^monitor=config_drift_monitor host=localhost status=OK ' || {
  echo "allowlisted config drift should be ignored" >&2
  echo "$out" >&2
  exit 1
}

printf '%s\n' "$out" | grep -q 'modified=0 added=0 removed=0' || {
  echo "unexpected config drift counters" >&2
  echo "$out" >&2
  exit 1
}

echo "config drift allowlist ok"
