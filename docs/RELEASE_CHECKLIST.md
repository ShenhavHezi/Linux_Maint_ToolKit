# Release Checklist

## Prep
- [ ] Decide version and run `make release-prep VERSION=x.y.z`.
- [ ] Place release notes under `docs/release_notes/` (archive), not `dist/`.
- [ ] Ensure `VERSION`, `docs/README.md`, and `docs/INDEX.md` all point at the same current release notes file.
- [ ] Run `./tools/release_check.sh`.
- [ ] Run `./tools/release_audit.sh`.
- [ ] Run `make lint` and `make test`.

## Breaking changes audit
- [ ] Confirm `docs/schemas/*.json` updated if output changed.
- [ ] Confirm `status_json_contract_version` was bumped if required.
- [ ] Confirm summary contract lines remain compatible.
- [ ] Note breaking changes explicitly in release notes.

## Build
- [ ] Build release tarball + checksums: `make release VERSION=x.y.z` (includes `--with-tarball`).
- [ ] `tools/release.sh` runs `release_check` + `release_audit` by default (use `--skip-checks` only for emergency/manual workflows).
- [ ] Optional manual build: `./tools/make_tarball.sh` (writes `dist/SHA256SUMS`).
- [ ] (Optional) Sign tarball if using GPG.

## Verify
- [ ] Verify tarball: `linux-maint verify-release dist/Linux_Maint_ToolKit-*.tgz --sums dist/SHA256SUMS`.
- [ ] Confirm `verify-release` passes required tarball members (`install.sh`, CLI/lib payload, plugin index, matching release notes).
- [ ] Or run: `make verify-release` (runs release checks/audit + tarball verification).
- [ ] Smoke test install in a clean environment.

## Publish
- [ ] Tag release in git.
- [ ] Tag push triggers a draft release on GitHub (review/edit notes from `CHANGELOG.md` Unreleased).
- [ ] Upload tarball + checksums.
- [ ] Publish release notes.
