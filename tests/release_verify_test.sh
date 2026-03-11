#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

mkdir -p "$workdir/dist"

mkdir -p "$workdir/bin" "$workdir/lib" "$workdir/tools" "$workdir/plugins" "$workdir/docs/release_notes"
printf '#!/usr/bin/env bash\n' > "$workdir/install.sh"
printf '#!/usr/bin/env bash\n' > "$workdir/bin/linux-maint"
printf '#!/usr/bin/env bash\n' > "$workdir/run_full_health_monitor.sh"
printf '#!/usr/bin/env bash\n' > "$workdir/lib/linux_maint.sh"
printf '#!/usr/bin/env bash\n' > "$workdir/lib/linux_maint_conf.sh"
printf '#!/usr/bin/env bash\n' > "$workdir/lib/linux_maint_runtime.sh"
printf '#!/usr/bin/env bash\n' > "$workdir/lib/linux_maint_admin.sh"
printf '#!/usr/bin/env bash\n' > "$workdir/lib/linux_maint_help.sh"
printf '#!/usr/bin/env bash\n' > "$workdir/lib/linux_maint_tui.sh"
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
tarball="$workdir/dist/Linux_Maint_ToolKit-v0.0.0-deadbeef.tgz"
printf 'version=v0.0.0\ncommit=deadbeef\n' > "$workdir/BUILD_INFO"
printf '0.0.0\n' > "$workdir/VERSION"
( cd "$workdir" && tar -czf "$tarball" ./install.sh ./bin ./lib ./tools ./plugins ./docs ./run_full_health_monitor.sh ./BUILD_INFO ./VERSION )

( cd "$workdir/dist" && sha256sum "$(basename "$tarball")" > SHA256SUMS )

# positive path
bash "$ROOT_DIR/tools/verify_release.sh" "$tarball" --sums "$workdir/dist/SHA256SUMS" >/dev/null

# tamper path must fail
printf 'tamper\n' >> "$tarball"
set +e
out="$(bash "$ROOT_DIR/tools/verify_release.sh" "$tarball" --sums "$workdir/dist/SHA256SUMS" 2>&1)"
rc=$?
set -e
if [[ "$rc" -eq 0 ]]; then
  echo "expected checksum verification failure on tampered tarball" >&2
  exit 1
fi
echo "$out" | grep -Eq 'FAILED|No such file|ERROR|warning' || {
  echo "unexpected verify output: $out" >&2
  exit 1
}

echo "release verify ok"
