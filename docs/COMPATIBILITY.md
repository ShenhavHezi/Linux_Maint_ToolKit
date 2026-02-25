# Compatibility matrix

This toolkit is designed to run in constrained or offline environments with a minimal, bash-only runtime.

## Supported / target environments

Primary target:
- RHEL 9 (and compatible variants)

Expected to work (best-effort):
- Other modern RHEL-like distros with systemd and standard coreutils
- Debian/Ubuntu-like systems with systemd and standard coreutils

If you are on an older distro or a non-systemd environment, expect partial coverage and SKIPs.

## Runtime requirements

| Component | Minimum | Notes |
| --- | --- | --- |
| bash | 4.2+ | Needed for arrays and `[[ ... ]]` usage |
| python3 | 3.6+ | Used for JSON tooling and diff/report helpers |
| coreutils | standard | `awk`, `grep`, `sed`, `sort`, `paste`, `head`, `tail`, `find`, `mktemp` |
| systemd | 219+ | Required for service/timer status and unit checks |

## Optional tools by monitor

Many monitors degrade to `SKIP` or `WARN` if optional tools are missing. Use:

```bash
linux-maint deps
```

This prints a per-monitor manifest of required vs optional tools.

## SSH compatibility

Remote checks use OpenSSH. Supported options are limited to safe, non-shell inputs. If you override SSH behavior:

```bash
linux-maint run --ssh-opts "-o BatchMode=yes -o ConnectTimeout=5"
```

See `docs/reference.md` for SSH policy and guardrails.
