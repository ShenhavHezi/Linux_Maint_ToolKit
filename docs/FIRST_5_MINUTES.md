# First 5 Minutes

This page is for a new operator who wants one short, reliable path from zero to a useful first result.

## Goal

In the first five minutes, you should be able to:

1. confirm the toolkit runs
2. validate config and prerequisites
3. preview what a run will do
4. execute a first run
5. review the result

## Fastest safe path: repo mode

Use this when you are evaluating the toolkit, developing locally, or do not want to touch system-wide paths yet.

```bash
git clone https://github.com/ShenhavHezi/Linux_Maint_ToolKit.git
cd Linux_Maint_ToolKit
./bin/linux-maint init --minimal
./bin/linux-maint check
./bin/linux-maint run --plan
./bin/linux-maint run
./bin/linux-maint status --verbose
./bin/linux-maint menu
```

What to expect:

- repo-mode artifacts go under `.logs/`
- missing optional inputs may appear as `SKIP`, which is normal on a first run
- `linux-maint menu` gives you the same flow visually: `Quickstart`, `Overview`, `Run`, `Triage`, `Share`

## Fastest safe path: installed mode

Use this when you want system-wide commands, timers, and persistent host operation.

```bash
sudo ./install.sh --with-user --with-timer --with-logrotate
sudo linux-maint init --minimal
sudo linux-maint check
sudo linux-maint run --plan
sudo linux-maint run
sudo linux-maint status --verbose
sudo linux-maint menu
```

What to expect:

- installed-mode config defaults to `/etc/linux_maint`
- installed-mode logs default to `/var/log/health`
- some checks need root or `sudo` to read privileged state

## If the first run shows problems

Use this order:

```bash
linux-maint doctor
linux-maint diff
linux-maint pack-logs --out /tmp
```

If you prefer the menu:

1. `Overview`
2. `Triage`
3. `Share`

## If the first run shows SKIPs

That usually means optional inputs are not configured yet. Common examples:

- `network_monitor`: missing target file
- `cert_monitor`: missing certificate inventory
- `backup_check`: missing backup target file
- `ports_baseline_monitor`: missing baseline file

These are expected on a fresh setup. Use:

```bash
linux-maint status --expected-skips
linux-maint doctor
```

## Best next step after the first 5 minutes

Pick one:

- Read [configuration.md](configuration.md) if you want broader monitor coverage
- Read [troubleshooting.md](troubleshooting.md) if you are already debugging a problem
- Read [UPGRADE.md](UPGRADE.md) if you plan to manage installed hosts over time
- Read [ARTIFACTS.md](ARTIFACTS.md) if you want support bundles, exports, or release verification
