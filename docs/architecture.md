# Architecture

High-level structure, runtime paths, and artifact flow for `linux-maint`.

Use this page when you want the system map. For exact flags, contracts, and file lists, use [reference.md](reference.md).

## What the toolkit is

`linux-maint` is a Bash-first operations toolkit with three main layers:

1. a command surface: `linux-maint`
2. a wrapper/runtime layer: `run_full_health_monitor.sh`
3. monitor and helper libraries under `lib/`, `monitors/`, and `tools/`

The design goal is simple:
- run local or fleet health checks
- emit machine-stable summary lines and JSON contracts
- preserve human-friendly operator workflows on top of those artifacts

## Operating modes

The same codebase supports three practical modes:

- **Repo mode**
  - run directly from a checkout
  - defaults to repo-local config and log paths
  - safest for evaluation, development, and CI
- **Installed mode**
  - installed under a prefix such as `/usr/local`
  - uses `/etc/linux_maint`, `/var/log/health`, and `/var/lib/linux_maint`
  - intended for long-lived host operation
- **RPM mode**
  - same logical behavior as installed mode
  - paths follow RPM-friendly locations such as `/usr`, `/usr/libexec`, and packaged systemd units

The CLI and menu try to stay mode-aware so operator hints, writable-path checks, and defaults match the active layout.

## Repo map (where to look)

- Run wrapper: `run_full_health_monitor.sh`
- CLI: `bin/linux-maint` (installed as `linux-maint`)
- Monitors: `monitors/` (each emits `monitor=... status=...` summary lines)
- Shared Bash library: `lib/linux_maint.sh`
- Config templates: `etc/linux_maint/` (copy to `/etc/linux_maint/`)
- Operator docs: `docs/`
- Tools (release/lint helpers): `tools/`
- Tests: `tests/`

## Runtime layers

### 1. Command layer

`linux-maint` is the primary operator entry point. It provides:
- human commands such as `status`, `report`, `check`, `doctor`, `pack-logs`
- machine-facing JSON/export commands
- the TUI menu
- install/upgrade/release helper entry points

This layer should stay thin: command dispatch, mode detection, and rendering. Heavy runtime behavior belongs in helpers and libraries.

### 2. Wrapper layer

`run_full_health_monitor.sh` is the execution orchestrator for full runs. It:
- resolves config, host lists, and monitor sets
- loads shared library functions
- runs monitors in a controlled order
- enforces locks, timeouts, and run metadata
- aggregates summary lines into log and JSON artifacts

### 3. Monitor layer

Each script under `monitors/` is responsible for one domain:
- service health
- network reachability
- certificates
- patch state
- storage
- drift/baselines
- backup freshness
- inventory/export

The monitor contract is intentionally narrow: emit stable summary lines and write detail to stderr/logs.

### 4. Artifact and reporting layer

Most operator commands after `run` are readers, not collectors. `status`, `report`, `trend`, `history`, `metrics`, `diff`, and parts of the menu primarily consume artifacts written by the wrapper.

That split matters:
- collection happens once in the wrapper
- reporting reuses the same artifacts for human and JSON views
- automation can depend on stable file and schema outputs instead of scraping terminal output

## Data flow

```text
linux-maint (CLI)
  ├─ run -> run_full_health_monitor.sh (wrapper)
  │        ├─ loads lib/linux_maint.sh + config
  │        ├─ executes monitors/*.sh
  │        ├─ captures monitor=... summary lines
  │        ├─ writes summary log + summary json
  │        └─ writes run metadata (last_status_full)
  └─ status/doctor/logs -> read artifacts and render operator views
```

Primary artifact flow:
- Monitors emit contract lines (`monitor=... host=... status=... reason=...`).
- Wrapper aggregates lines into timestamped summary files and latest symlinks.
- CLI status/reporting commands parse those artifacts for human and JSON outputs.

## Artifact model

The architecture is built around a few durable artifacts:

- wrapper logs
- summary line logs
- summary JSON
- last-run status metadata
- run index history
- optional audit log and support bundles

This gives the project a clean separation:
- **collection artifacts** are written once
- **presentation commands** can be retried safely
- **CI and external tooling** can consume JSON and summary files directly

## Configuration precedence

The effective configuration is layered:

1. built-in defaults from scripts and libraries
2. installed or repo-local config files
3. environment overrides
4. command flags

Repo mode and installed mode intentionally resolve different default roots, but the command behavior should stay logically equivalent.

## Safety boundaries

The main safety rules in the current design are:

- read-only commands should not mutate repo-local state just to render output
- machine-readable output must stay stable and clean
- wrapper and monitor failures should propagate clearly instead of degrading silently
- repo mode should avoid installed-mode assumptions like forced `sudo` or `/etc`-only paths
- advanced surfaces such as `serve`, `agent`, `policy`, `federate`, and plugins stay opt-in

## Extension points

The toolkit is extensible in a few deliberate places:

- **custom monitors** and local monitor config
- **plugins** via the plugin registry and packaged plugin index
- **JSON/export contracts** for external tooling
- **support bundles** for escalation and offline transfer

These extension points matter more than UI polish, because they determine whether the toolkit can integrate cleanly into real operational workflows.

## How to read the rest of the docs

- Use [FIRST_5_MINUTES.md](FIRST_5_MINUTES.md) for the shortest operator path
- Use [QUICK_REFERENCE.md](QUICK_REFERENCE.md) for common commands
- Use [reference.md](reference.md) for exact command behavior and schema contracts
- Use [troubleshooting.md](troubleshooting.md) for live problem handling
- Use [UPGRADE.md](UPGRADE.md) and [ARTIFACTS.md](ARTIFACTS.md) for lifecycle and escalation work
