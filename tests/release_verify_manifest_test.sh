#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT_DIR/tests/testlib.sh"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

mkdir -p "$workdir/dist"

mkdir -p "$workdir/bin" "$workdir/lib" "$workdir/tools" "$workdir/plugins" "$workdir/docs/release_notes"
printf '#!/usr/bin/env bash\n' > "$workdir/install.sh"
printf '#!/usr/bin/env bash\n' > "$workdir/bin/linux-maint"
printf '#!/usr/bin/env bash\n' > "$workdir/run_full_health_monitor.sh"
testlib_write_release_lib_stubs "$workdir/lib"
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

checksum="$(sha256sum "$tarball" | awk '{print $1}')"
( cd "$workdir/dist" && sha256sum "$(basename "$tarball")" > SHA256SUMS )
cat > "$workdir/dist/release_provenance.json" <<EOF
{
  "release_provenance_version": 1,
  "artifact": "$(basename "$tarball")",
  "sha256": "$checksum",
  "sha256sums": "SHA256SUMS",
  "version": "0.0.0",
  "tag": "v0.0.0",
  "commit": "deadbeef",
  "branch": "main",
  "built_at_utc": "2026-03-11T00:00:00Z",
  "build_info": "BUILD_INFO",
  "signature": null
}
EOF

bash "$ROOT_DIR/tools/verify_release.sh" "$tarball" --sums "$workdir/dist/SHA256SUMS" --manifest "$workdir/dist/release_provenance.json" >/dev/null

python3 - "$workdir/dist/release_provenance.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["sha256"] = "0" * 64
path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
PY

set +e
out="$(bash "$ROOT_DIR/tools/verify_release.sh" "$tarball" --sums "$workdir/dist/SHA256SUMS" --manifest "$workdir/dist/release_provenance.json" 2>&1)"
rc=$?
set -e
[[ "$rc" -ne 0 ]] || {
  echo "verify_release.sh succeeded with mismatched provenance manifest" >&2
  exit 1
}
grep -q 'provenance manifest mismatch for sha256' <<< "$out" || {
  echo "verify_release.sh did not flag provenance manifest mismatch" >&2
  echo "$out" >&2
  exit 1
}

echo "release verify manifest ok"
