# Release Notes v0.3.4

- Version: 0.3.4
- Date (UTC): 2026-03-10
- Git tag: v0.3.4

## Highlights
- Added a dedicated `linux-maint upgrade` workflow for verified tarball upgrades, with rollback manifests, config snapshots, installed payload inventory, and post-upgrade verification.
- Hardened the install/release path across tarball verification, RPM payload parity, RPM lifecycle testing, valid packaged systemd units, and repo-vs-installed layout behavior.
- Expanded Rocky Linux 9 / RHEL9-compatible CI coverage and fixed the install-lifecycle and bash-compat failures that were specific to that platform family.
- Continued polishing the operator experience with an arrow-first workflow menu, calmer section grouping, better fallback prompts, and richer support-bundle handoff metadata.
- Reduced `bin/linux-maint` complexity by extracting runtime/path bootstrap and install/release/admin handlers into dedicated support libraries.

## Upgrade and install workflow
- Added `linux-maint upgrade <tarball>` for installed-mode tarball upgrades.
- The upgrade flow now:
  - runs `verify-release`
  - extracts the release into a working directory
  - snapshots the current config directory
  - records installed payload inventory
  - writes rollback guidance and a JSON manifest under the active state dir
  - runs the extracted `install.sh`
  - finishes with post-upgrade `verify-install`
- Added installed-prefix autodetection improvements so installed helpers and shared payloads resolve correctly without forcing `PREFIX`, including non-`/usr/local` layouts.
- Added installer rollback safety so partial upgrades restore the prior payload, including touched systemd units and logrotate config.

## Release, packaging, and RPM hardening
- Tightened release discipline so:
  - `VERSION` must stay in strict `x.y.z` form
  - `CHANGELOG.md` must contain the current release entry
  - the current release notes must match the version, tag, and date fields
  - tarball verification requires the expected CLI/lib/helper payload and matching release notes
- Restored valid RPM systemd units and aligned the RPM timer schedule with the installer’s daily `02:15` cadence.
- Fixed RPM packaging payload parity so the packaged install now includes the same support libraries and installed-mode helpers as `install.sh`.
- Added real Rocky-style RPM lifecycle coverage for:
  - install
  - upgrade
  - reinstall
  - remove
  - config preservation across package operations

## Compatibility and CI
- Hardened Rocky Linux 9 CI bootstrap and compat coverage:
  - shell-agnostic dependency bootstrap
  - exec-bit normalization after checkout
  - focused compat smoke selection for EL9
  - install lifecycle prerequisites and archive-checkout handling
- Fixed the release/upgrade tests to work in archive-style checkouts and in environments without `diffutils`.
- Kept release verification and upgrade coverage in CI so regressions in release artifacts or upgrade paths fail earlier.

## Operator UX and support workflow
- Refined `linux-maint menu` around a calmer workflow model:
  - arrow-first selection instead of shortcut-first interaction
  - simplified top-level workflow grouping
  - improved `dialog` / `whiptail` prompts with clearer section/state/recommended-action context
- Fixed duplicate menu rendering in `gum` mode and preserved clean return-to-main behavior after subcommand failures.
- Strengthened support bundles so `pack-logs` now includes:
  - `meta/bundle_manifest.txt`
  - `meta/redaction_report.txt`
  - `meta/support_handoff.txt`
- Improved bundle collection behavior so installed metadata paths, log symlinks, and gpg prerequisite failures are handled more predictably.

## Maintainability
- Split `bin/linux-maint` further by extracting:
  - runtime/path initialization helpers into `lib/linux_maint_runtime.sh`
  - install/release/admin command handlers into `lib/linux_maint_admin.sh`
- Previously extracted help rendering remains in `lib/linux_maint_help.sh`, so the CLI entrypoint now carries less install/release/bootstrap logic directly.
- Updated installed-layout, release, and temp-prefix tests so the new support libraries are validated in repo mode, installed mode, smoke, and release tarball paths.

## Compatibility notes
- No intended schema-breaking release.
- This release is mainly about safer upgrades, more reliable packaging, stronger Rocky/RHEL9 compatibility, and lower maintenance risk inside the CLI entrypoint.
- Operators upgrading from `v0.3.3` should use the new `linux-maint upgrade` path for tarball-based installs when possible, because it now records rollback metadata and runs post-upgrade verification automatically.
