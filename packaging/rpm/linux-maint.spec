Name:           linux-maint
Version:        0.1.0
Release:        1.%{?commit}%{?dist}
Summary:        Linux maintenance/monitoring toolkit (wrapper + monitors + CLI)

License:        MIT
URL:            https://github.com/ShenhavHezi/linux_Maint_Scripts
Source0:        %{name}-%{version}.tar.gz

# Short git sha (passed by rpmbuild --define "commit <sha>")
%global commit %(echo %{?commit} | sed -e "s/[^0-9A-Za-z].*$//")

BuildArch:      noarch

Requires:       bash
Requires:       coreutils
Requires:       util-linux
Requires:       openssh-clients
Requires:       python3

# systemd integration
Requires(post): systemd
Requires(preun): systemd

%description
linux-maint is a Linux fleet maintenance/monitoring toolkit.
It provides a wrapper runner, monitors, and a CLI for running checks, status/diff, and diagnostics.

%prep
%setup -q

%build
# no build step

%install
rm -rf %{buildroot}

# Use /usr (RPM best practice)
install -d %{buildroot}/usr/bin
install -d %{buildroot}/usr/sbin
install -d %{buildroot}/usr/lib
install -d %{buildroot}/usr/libexec/linux_maint
install -d %{buildroot}/usr/share/linux_maint
install -d %{buildroot}/usr/share/linux_maint/templates

install -m 0755 bin/linux-maint %{buildroot}/usr/bin/linux-maint
install -m 0755 run_full_health_monitor.sh %{buildroot}/usr/sbin/run_full_health_monitor.sh
install -m 0755 lib/linux_maint.sh %{buildroot}/usr/lib/linux_maint.sh

# monitors + tools
install -m 0755 monitors/*.sh %{buildroot}/usr/libexec/linux_maint/
install -m 0755 tools/summary_diff.py %{buildroot}/usr/libexec/linux_maint/summary_diff.py

# templates for init
cp -a etc/linux_maint %{buildroot}/usr/share/linux_maint/templates/

# systemd units
install -d %{buildroot}/usr/lib/systemd/system
install -m 0644 packaging/rpm/linux-maint.service %{buildroot}/usr/lib/systemd/system/linux-maint.service
install -m 0644 packaging/rpm/linux-maint.timer %{buildroot}/usr/lib/systemd/system/linux-maint.timer

# NOTE: If the repo does not carry unit files, you should add them to packaging/rpm/ and install from there.

%post
# Enable/start timer by default (can be disabled by setting LM_ENABLE_TIMER=0)
if [ "${LM_ENABLE_TIMER:-1}" = "1" ]; then
  /usr/bin/systemctl daemon-reload >/dev/null 2>&1 || true
  /usr/bin/systemctl enable --now linux-maint.timer >/dev/null 2>&1 || true
fi

%preun
if [ $1 -eq 0 ]; then
  /usr/bin/systemctl disable --now linux-maint.timer >/dev/null 2>&1 || true
  /usr/bin/systemctl daemon-reload >/dev/null 2>&1 || true
fi

%files
/usr/bin/linux-maint
/usr/sbin/run_full_health_monitor.sh
/usr/lib/linux_maint.sh
/usr/libexec/linux_maint/*
/usr/share/linux_maint/
/usr/lib/systemd/system/linux-maint.service
/usr/lib/systemd/system/linux-maint.timer

%changelog
* Thu Feb 05 2026 shenhav <shenhav@localhost> - 0.1.0-1
- Initial RPM packaging
