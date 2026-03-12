# Release Notes v0.3.6

- Version: 0.3.6
- Date (UTC): 2026-03-12
- Git tag: v0.3.6

[Release history](https://github.com/ShenhavHezi/Linux_Maint_ToolKit/blob/main/docs/release_notes/README.md) · [Upgrade guide](https://github.com/ShenhavHezi/Linux_Maint_ToolKit/blob/main/docs/UPGRADE.md)

## Highlights

- Continued the maintainability split of `bin/linux-maint`, moving more command surfaces into support libraries while keeping the CLI contract stable.
- Reorganized the test suite by operational area so install, release, menu, wrapper, runtime, core, advanced, reporting, and admin-ops coverage are easier to navigate and maintain.
- Hardened advanced command validation again across `plugin`, `serve`, `agent`, `policy`, `gate`, `federate`, and `predict`.
- Tightened release discipline so release-note generation, release indexes, and workflow paths stay aligned after large repo reorganizations.

## CLI and support-library maintainability

- Split more command surfaces out of `bin/linux-maint`, including:
  - `doctor`
  - `init`
  - admin-ops commands such as `notify`, `ticket`, `audit-log`, and `cm-hook`
  - menu workflow routing
  - `run` planning and execution helpers
  - inspect helpers like `list-monitors` and `lint-summary`
  - `diff`, `logs`, and `gate`
- Centralized support-library payload tracking through `lib/RELEASE_LIBS.txt`, so install, RPM, tarball, upgrade, and verify paths follow one source of truth.
- Reduced overlap between support libraries by centralizing runtime defaults and artifact-path helpers in `linux_maint_runtime.sh`.

## Test and CI maintainability

- Grouped the test suite into clearer operational areas:
  - `tests/install`
  - `tests/release`
  - `tests/menu`
  - `tests/wrapper`
  - `tests/reporting`
  - `tests/core`
  - `tests/runtime`
  - `tests/advanced`
  - `tests/adminops`
- Updated `tests/smoke.sh`, maintainer docs, and CI workflow paths to match the new layout.
- Tightened workflow guards so stale pre-regroup test paths are caught quickly instead of breaking later in CI.

## Advanced command hardening

- `plugin` handling is stricter around:
  - invalid plugin names
  - invalid or non-object `plugin.json`
  - path-escape reads in verification and trust/provenance flows
  - corrupt registries during install, update, and verification
- `serve` now validates:
  - missing flag values
  - port ranges
  - nested contract markers in `/report` and `/metrics` upstream payloads
  - malformed or incomplete upstream JSON shapes without falling through into tracebacks
- `agent`, `policy`, `gate`, `federate`, `predict`, and `ai-assist` now reject more malformed inputs cleanly and preserve clearer `rc=2` behavior for invalid user input.

## Release and workflow fixes

- Fixed release generation so new release notes get the correct `# Release Notes vX.Y.Z` title instead of inheriting the template header.
- Updated the release-note helper to refresh both:
  - `docs/README.md`
  - `docs/release_notes/README.md`
- Fixed CI workflow references after the test-suite regroup, including compat, install-lifecycle, and RPM lifecycle jobs.
- Fixed a regroup regression in `lm_for_each_host_rc_test.sh` that broke compat smoke on Debian and Ubuntu.
- Fixed a regroup regression in `per_monitor_timeout_override_test.sh` that broke the runtime smoke slice after the `tests/runtime/` move.

## Compatibility notes

- No intended breaking CLI or schema changes in this release.
- RHEL 9 remains the primary platform target, with Rocky Linux 9 used as the compatible RPM CI lane.
- Operators upgrading from `v0.3.5` should continue using `linux-maint upgrade` for tarball-based installs and `linux-maint verify-install` after the upgrade completes.
