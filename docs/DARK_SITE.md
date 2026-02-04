# Dark-site / air-gapped deployment guide

This project supports offline installation by generating a self-contained tarball.

## 1) Build the tarball (connected workstation)

```bash
git clone https://github.com/ShenhavHezi/linux_Maint_Scripts.git
cd linux_Maint_Scripts

./tools/make_tarball.sh
# output: dist/linux_Maint_Scripts-<version>-<sha>.tgz
```

Optional (recommended) integrity file:

```bash
sha256sum dist/linux_Maint_Scripts-*.tgz > dist/SHA256SUMS
```

## 2) Transfer into the offline environment (staging / hop)

Move the tarball using your approved process. In many environments this is a multi-step “hop”, for example:

- connected workstation → staging machine / scanning station → removable media → offline network → target servers

Copy:
- `dist/linux_Maint_Scripts-*.tgz`
- `dist/SHA256SUMS` (optional)

On the offline side you can verify:

```bash
sha256sum -c SHA256SUMS
```

## 3) Install on the offline server(s)

On each target server:

```bash
tar -xzf linux_Maint_Scripts-*.tgz
cd linux_Maint_Scripts-*

sudo ./install.sh --with-logrotate
# optional:
# sudo ./install.sh --with-user --with-timer --with-logrotate

# verify:
linux-maint version || true
sudo linux-maint status || true
```

## 4) Run manually (quick test)

```bash
sudo linux-maint run
sudo linux-maint logs 200
```

## Notes

- Installed mode is intended to run as root (or via sudo) because it uses `/var/log` and `/var/lock`.
- For per-monitor configuration, see files under `/etc/linux_maint/` (created by the installer).
- Full reference: [`reference.md`](reference.md)
