#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

mkdir -p "$workdir/dist" "$workdir/bin" "$workdir/lib" "$workdir/tools" "$workdir/plugins" "$workdir/docs/release_notes"
printf '#!/usr/bin/env bash\n' > "$workdir/bin/linux-maint"
printf '#!/usr/bin/env bash\n' > "$workdir/install.sh"
printf '#!/usr/bin/env bash\n' > "$workdir/run_full_health_monitor.sh"
printf '#!/usr/bin/env bash\n' > "$workdir/lib/linux_maint.sh"
printf '#!/usr/bin/env bash\n' > "$workdir/lib/linux_maint_conf.sh"
printf '#!/usr/bin/env bash\n' > "$workdir/lib/linux_maint_runtime.sh"
printf '#!/usr/bin/env bash\n' > "$workdir/lib/linux_maint_admin.sh"
printf '#!/usr/bin/env bash\n' > "$workdir/lib/linux_maint_help.sh"
printf '#!/usr/bin/env bash\n' > "$workdir/lib/linux_maint_tui.sh"
printf '#!/usr/bin/env bash\n' > "$workdir/lib/linux_maint_config.sh"
printf '#!/usr/bin/env bash\n' > "$workdir/lib/linux_maint_reporting.sh"
printf '#!/usr/bin/env bash\n' > "$workdir/lib/linux_maint_advanced.sh"
printf '#!/usr/bin/env bash\n' > "$workdir/lib/linux_maint_history.sh"
printf '#!/usr/bin/env bash\n' > "$workdir/tools/verify_release.sh"
printf '#!/usr/bin/env bash\n' > "$workdir/tools/upgrade_release.sh"
printf '#!/usr/bin/env bash\n' > "$workdir/tools/pack_logs.sh"
printf '#!/usr/bin/env bash\n' > "$workdir/tools/seed_known_hosts.sh"
printf 'print(\"ok\")\n' > "$workdir/tools/summary_diff.py"
printf '{}\n' > "$workdir/plugins/index.json"
printf '# notes\n' > "$workdir/docs/release_notes/release_notes_v0.0.0.md"
printf 'version=v0.0.0\ncommit=deadbeef\n' > "$workdir/BUILD_INFO"
printf '0.0.0\n' > "$workdir/VERSION"

tarball="$workdir/dist/Linux_Maint_ToolKit-v0.0.0-deadbeef.tgz"
( cd "$workdir" && tar -czf "$tarball" ./bin ./lib ./tools ./plugins ./docs ./run_full_health_monitor.sh ./BUILD_INFO ./VERSION )
( cd "$workdir/dist" && sha256sum "$(basename "$tarball")" > SHA256SUMS )

set +e
out="$(bash "$ROOT_DIR/tools/verify_release.sh" "$tarball" --sums "$workdir/dist/SHA256SUMS" 2>&1)"
rc=$?
set -e
[[ "$rc" -ne 0 ]] || {
  echo "verify_release.sh succeeded with missing install.sh" >&2
  exit 1
}
grep -q 'tarball missing required member: install.sh' <<< "$out" || {
  echo "verify_release.sh did not flag missing install.sh" >&2
  echo "$out" >&2
  exit 1
}

echo "release verify members ok"
