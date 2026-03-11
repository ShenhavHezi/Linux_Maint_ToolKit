# Fleet And Operations Guide

This page is for real host and fleet operation after you understand the basic local flow.

If you just want the first successful run, use [FIRST_5_MINUTES.md](FIRST_5_MINUTES.md).

## Recommended operations path

1. install or confirm the intended mode
2. initialize minimal config
3. validate with `check`
4. preview with `run --plan`
5. execute `run`
6. review `status`, `report`, and `diff`
7. package artifacts when escalation is needed

## Installed host setup

```bash
sudo ./install.sh --with-user --with-timer --with-logrotate
sudo linux-maint verify-install
sudo linux-maint init --minimal
sudo linux-maint check
```

## Fleet run workflow

```bash
sudo linux-maint run --group prod --parallel 10 --plan
sudo linux-maint run --group prod --parallel 10
sudo linux-maint status --verbose
sudo linux-maint report --short
```

Use `hosts.d` groups when you want repeatable scopes instead of ad-hoc host lists.

## SSH strict mode

If you require strict host-key verification:

```bash
sudo /usr/local/libexec/linux_maint/seed_known_hosts.sh --hosts-file /etc/linux_maint/servers.txt
echo "LM_SSH_KNOWN_HOSTS_MODE=strict" | sudo tee -a /etc/linux_maint/linux-maint.conf >/dev/null
```

Optional stronger pinning:

```bash
echo "LM_SSH_KNOWN_HOSTS_PIN_FILE=/var/lib/linux_maint/known_hosts.pinned" | sudo tee -a /etc/linux_maint/linux-maint.conf >/dev/null
sudo /usr/local/libexec/linux_maint/seed_known_hosts.sh --hosts-file /etc/linux_maint/servers.txt --check
```

## CI or deployment gate

Create a small policy file:

```bash
cat > policy.conf <<'EOF'
max_crit=0
max_warn=5
max_unknown=10
max_skip=200
require_overall=
EOF
```

Then gate on current health:

```bash
linux-maint run
linux-maint gate --policy policy.conf
linux-maint gate --policy policy.conf --json
```

If the gate fails, attach:

```bash
linux-maint report --short
linux-maint pack-logs --out /tmp
```

## Prometheus textfile flow

The wrapper can refresh:

```text
/var/lib/node_exporter/textfile_collector/linux_maint.prom
```

Use:

```bash
linux-maint metrics --prom
```

or schedule the wrapper/service path for periodic refresh.

## Companion docs

- [configuration.md](configuration.md)
- [COMPATIBILITY.md](COMPATIBILITY.md)
- [DARK_SITE.md](DARK_SITE.md)
- [UPGRADE.md](UPGRADE.md)
- [ARTIFACTS.md](ARTIFACTS.md)
