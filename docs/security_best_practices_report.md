# Security Best Practices Report

Date: 2026-02-22
Scope: Bash scripts in `bin/`, `lib/`, `monitors/`, and related tooling.

Note: The `security-best-practices` skill does not include Bash-specific reference docs. This report is based on common shell security hardening practices.

## Executive Summary
Overall, the project already has several good security controls (SSH option validation, SSH allowlists, use of `mktemp`, and safe defaults). The highest-risk issues are centered on **remote command construction** in `network_monitor.sh` and **host-derived file paths** in `user_monitor.sh`. These are exploitable if configuration inputs are malicious or compromised, which is a realistic threat model for shared fleet configs.

## Findings

### High (1)

**SBP-1: Remote command injection via `network_monitor` targets and params**
- **Impact:** A malicious entry in `network_targets.txt` (or param overrides) can inject shell tokens into remote commands, executing unintended commands on monitored hosts.
- **Where:**
  - `monitors/network_monitor.sh:97` (ping target interpolated into remote shell command)
  - `monitors/network_monitor.sh:133` (host/port interpolated into `/dev/tcp` command)
  - `monitors/network_monitor.sh:145-147` (nc with quoted host/port)
  - `monitors/network_monitor.sh:175` (curl with URL interpolated into remote shell command)
- **Details:** Values from the targets file (e.g., `target`, `host:port`, URL) and per-row params (timeouts/counts) are embedded into a remote shell string. If a target contains quotes or shell metacharacters, it can break out of quoting and inject arbitrary commands.
- **Recommendation:**
  1. **Validate input strictly** before use. For example:
     - ping target: only allow `[A-Za-z0-9._:-]` and reject quotes/whitespace.
     - TCP host/port: enforce `host:port` with a numeric port and a safe host pattern.
     - HTTP URL: validate scheme + host + optional path with a conservative regex, or reject quotes/whitespace.
  2. **Avoid shell interpolation** where possible by passing arguments to `ssh` as separate argv elements (no `bash -lc`). For multi-command fallbacks, prefer two separate `lm_ssh` calls instead of `cmd1 || cmd2` inside a single shell string.
  3. Add tests that ensure invalid targets are rejected (and produce a safe `SKIP`/`UNKNOWN` summary).

### Medium (1)

**SBP-2: Hostname path traversal in `user_monitor` baseline files**
- **Impact:** A crafted host entry (e.g., `../../etc/shadow`) in `servers.txt` could write baseline snapshots outside the intended directory, potentially overwriting sensitive files.
- **Where:**
  - `monitors/user_monitor.sh:112` (`users_base_file` derived from `${host}`)
  - `monitors/user_monitor.sh:152` (`sudo_base_file` derived from `${host}`)
- **Details:** Hostnames are used to build file paths directly. There is no validation to prevent path separators or traversal sequences. If an attacker can modify `servers.txt` or host group files, they can redirect output.
- **Recommendation:**
  1. Sanitize hostnames to a safe filename (e.g., allow `[A-Za-z0-9._-]` only; reject others).
  2. Alternatively, map hosts to a safe filename (e.g., replace unsafe characters with `_`), and log a warning when normalization occurs.
  3. Add a unit test for host sanitization in `user_monitor`.

## Positive Notes
- `LM_SSH_OPTS` validation in `lib/linux_maint.sh` reduces risky injection via SSH options.
- Use of `mktemp` for temp files is consistent and safer than predictable paths.
- SSH allowlist support provides a strong defense-in-depth option when enabled.

## Suggested Next Steps
1. Decide whether to **reject** unsafe targets (strict) or **sanitize** them (lenient).
2. Implement input validation in `network_monitor.sh` and host sanitization in `user_monitor.sh`.
3. Add tests to lock in the new behaviors.

