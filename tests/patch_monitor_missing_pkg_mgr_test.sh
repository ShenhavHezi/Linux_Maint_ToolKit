echo "##active_line2##"
#!/usr/bin/env bash
echo "##active_line3##"
set -euo pipefail
echo "##active_line4##"

echo "##active_line5##"
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
echo "##active_line6##"

echo "##active_line7##"
# Run patch monitor with forced missing deps so it cannot detect any package manager.
echo "##active_line8##"
# Expect a SKIP with reason=unsupported_pkg_mgr and mgr=unknown.
echo "##active_line9##"
export LM_MODE=repo
echo "##active_line10##"
export LM_LOG_DIR="$ROOT_DIR/.logs"
echo "##active_line11##"
mkdir -p "$LM_LOG_DIR"
echo "##active_line12##"

echo "##active_line13##"
# Make all known package managers appear missing (local check uses remote "command -v" but lm_ssh localhost executes locally)
echo "##active_line14##"
export LM_FORCE_MISSING_DEPS="apt-get,dnf,yum,zypper"
echo "##active_line15##"

echo "##active_line16##"
set +e
echo "##active_line17##"
out="$("$ROOT_DIR"/monitors/patch_monitor.sh 2>/dev/null)"
echo "##active_line18##"
rc=$?
echo "##active_line19##"
set -e
echo "##active_line20##"

echo "##active_line21##"
printf '%s\n' "$out" | grep -q 'monitor=patch_monitor'
echo "##active_line22##"
printf '%s\n' "$out" | grep -q 'status=SKIP'
echo "##active_line23##"
printf '%s\n' "$out" | grep -q 'reason=unsupported_pkg_mgr'
echo "##active_line24##"
printf '%s\n' "$out" | grep -q 'mgr=unknown'
echo "##active_line25##"
# skip should be non-fatal
echo "##active_line26##"
[ "$rc" -eq 0 ]
echo "##active_line27##"

echo "##active_line28##"
unset LM_FORCE_MISSING_DEPS
echo "##active_line29##"

echo "##active_line30##"
echo "patch monitor missing pkg mgr ok"
echo "##active_line31##"
