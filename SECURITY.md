# Security Policy

## Supported Versions

This repository is maintained on a best-effort basis.

If you are running this in production, prefer pinned releases/tarballs and test changes in a staging environment first.

## Reporting a Vulnerability

If you believe you have found a security issue:

1. **Do not** open a public issue with exploit details.
2. Contact the maintainer via GitHub (open a minimal issue saying "security report" without details, or use a private channel if available).
3. Include:
   - affected script/monitor name
   - environment/distro
   - steps to reproduce
   - expected vs actual behavior

We will respond as soon as practical.

## Minimal-privilege guidance

Operational safety improves when linux-maint runs with the least required privileges:

- Use a dedicated SSH key for the monitoring node and restrict it to the monitoring user.
- Avoid agent forwarding (`-o ForwardAgent=no` is default).
- Prefer a dedicated known_hosts file (`LM_SSH_KNOWN_HOSTS_FILE`) and strict mode where possible.

If you need sudo for installed mode, use a constrained sudoers entry that only permits the linux-maint wrapper:

```
linuxmaint ALL=(root) NOPASSWD: /usr/local/sbin/run_full_health_monitor.sh
```

Adjust for your environment and consider additional restrictions such as `NOEXEC` or host-specific rules.
