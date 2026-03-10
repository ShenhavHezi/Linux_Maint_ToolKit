#!/usr/bin/env bash
set -euo pipefail

if [[ "${LM_RPM_LIFECYCLE_ALLOW_SYSTEM:-0}" != "1" ]]; then
  echo "SKIP: rpm lifecycle smoke requires LM_RPM_LIFECYCLE_ALLOW_SYSTEM=1" >&2
  exit 0
fi

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "SKIP: rpm lifecycle smoke requires root" >&2
  exit 0
fi

for cmd in dnf rpm rpmbuild rsync tar python3; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "SKIP: rpm lifecycle smoke requires $cmd" >&2
    exit 0
  }
done

TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CURRENT_VERSION="$(head -n 1 "$ROOT_DIR/VERSION" | tr -d '[:space:]')"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

old_tree="$workdir/old_tree"
new_tree="$workdir/new_tree"
old_out="$workdir/out_old"
new_out="$workdir/out_new"
old_work="$workdir/rpmbuild_old"
new_work="$workdir/rpmbuild_new"

copy_repo() {
  local dest="$1"
  mkdir -p "$dest"
  (
    cd "$ROOT_DIR"
    tar --exclude=.git --exclude=dist --exclude=.logs --exclude=.tmp_test -cf - .
  ) | tar -xf - -C "$dest"
}

next_patch_version() {
  python3 - "$1" <<'PY'
import sys
parts = sys.argv[1].strip().split(".")
if len(parts) != 3:
    raise SystemExit(1)
nums = [int(p) for p in parts]
nums[2] += 1
print(".".join(str(n) for n in nums))
PY
}

build_rpm_from_tree() {
  local tree="$1" version="$2" outdir="$3" work="$4"
  OUTDIR="$outdir" WORK="$work" "$tree/packaging/rpm/build_rpm.sh" "$version" >/dev/null
  find "$outdir/rpm" -maxdepth 1 -type f -name '*.rpm' | head -n 1
}

assert_file() {
  local path="$1" msg="$2"
  [[ -e "$path" ]] || {
    echo "$msg" >&2
    exit 1
  }
}

assert_missing() {
  local path="$1" msg="$2"
  [[ ! -e "$path" ]] || {
    echo "$msg" >&2
    exit 1
  }
}

copy_repo "$old_tree"
copy_repo "$new_tree"

NEW_VERSION="$(next_patch_version "$CURRENT_VERSION")"
printf '%s\n' "$NEW_VERSION" > "$new_tree/VERSION"

old_rpm="$(build_rpm_from_tree "$old_tree" "$CURRENT_VERSION" "$old_out" "$old_work")"
new_rpm="$(build_rpm_from_tree "$new_tree" "$NEW_VERSION" "$new_out" "$new_work")"

[[ -f "$old_rpm" && -f "$new_rpm" ]] || {
  echo "failed to build old/new rpms for lifecycle smoke" >&2
  exit 1
}

dnf -y remove linux-maint >/dev/null 2>&1 || true
rm -rf /etc/linux_maint /var/log/health /var/lib/linux_maint

LM_ENABLE_TIMER=0 dnf -y install "$old_rpm" >/dev/null
rpm -q --qf '%{VERSION}\n' linux-maint | grep -qx "$CURRENT_VERSION" || {
  echo "rpm install did not land expected old version $CURRENT_VERSION" >&2
  exit 1
}

linux-maint init >/dev/null
mkdir -p /var/log/health /var/lib/linux_maint
printf '# rpm-lifecycle-marker=%s\n' "$CURRENT_VERSION" >> /etc/linux_maint/linux-maint.conf
printf 'rpm_marker=%s\n' "$CURRENT_VERSION" > /etc/linux_maint/conf.d/rpm-lifecycle.conf

assert_file /usr/bin/linux-maint "rpm install missing linux-maint binary"
assert_file /usr/libexec/linux_maint/upgrade_release.sh "rpm install missing upgrade helper"
assert_file /usr/lib/systemd/system/linux-maint.service "rpm install missing service unit"
assert_file /usr/lib/systemd/system/linux-maint.timer "rpm install missing timer unit"

verify_out="$(linux-maint verify-install 2>&1 || true)"
printf '%s\n' "$verify_out" | grep -q '^verify-install ok$' || {
  echo "verify-install failed after rpm install" >&2
  echo "$verify_out" >&2
  exit 1
}

LM_ENABLE_TIMER=0 dnf -y upgrade "$new_rpm" >/dev/null
rpm -q --qf '%{VERSION}\n' linux-maint | grep -qx "$NEW_VERSION" || {
  echo "rpm upgrade did not land expected version $NEW_VERSION" >&2
  exit 1
}
linux-maint version | grep -q "^version=$NEW_VERSION$" || {
  echo "linux-maint version did not reflect upgraded rpm version $NEW_VERSION" >&2
  linux-maint version >&2 || true
  exit 1
}
grep -q "^# rpm-lifecycle-marker=$CURRENT_VERSION$" /etc/linux_maint/linux-maint.conf || {
  echo "rpm upgrade did not preserve linux-maint.conf customizations" >&2
  exit 1
}
grep -q "^rpm_marker=$CURRENT_VERSION$" /etc/linux_maint/conf.d/rpm-lifecycle.conf || {
  echo "rpm upgrade did not preserve conf.d overrides" >&2
  exit 1
}

verify_out="$(linux-maint verify-install 2>&1 || true)"
printf '%s\n' "$verify_out" | grep -q '^verify-install ok$' || {
  echo "verify-install failed after rpm upgrade" >&2
  echo "$verify_out" >&2
  exit 1
}

LM_ENABLE_TIMER=0 dnf -y reinstall "$new_rpm" >/dev/null
rpm -q --qf '%{VERSION}\n' linux-maint | grep -qx "$NEW_VERSION" || {
  echo "rpm reinstall changed installed version unexpectedly" >&2
  exit 1
}
grep -q "^rpm_marker=$CURRENT_VERSION$" /etc/linux_maint/conf.d/rpm-lifecycle.conf || {
  echo "rpm reinstall did not preserve conf.d overrides" >&2
  exit 1
}

verify_out="$(linux-maint verify-install 2>&1 || true)"
printf '%s\n' "$verify_out" | grep -q '^verify-install ok$' || {
  echo "verify-install failed after rpm reinstall" >&2
  echo "$verify_out" >&2
  exit 1
}

dnf -y remove linux-maint >/dev/null
assert_missing /usr/bin/linux-maint "rpm remove left linux-maint binary behind"
assert_missing /usr/libexec/linux_maint "rpm remove left helper directory behind"
assert_missing /usr/lib/systemd/system/linux-maint.service "rpm remove left service unit behind"
assert_missing /usr/lib/systemd/system/linux-maint.timer "rpm remove left timer unit behind"
grep -q "^# rpm-lifecycle-marker=$CURRENT_VERSION$" /etc/linux_maint/linux-maint.conf || {
  echo "rpm remove did not preserve config file" >&2
  exit 1
}
grep -q "^rpm_marker=$CURRENT_VERSION$" /etc/linux_maint/conf.d/rpm-lifecycle.conf || {
  echo "rpm remove did not preserve conf.d override" >&2
  exit 1
}

echo "rpm lifecycle smoke ok"
