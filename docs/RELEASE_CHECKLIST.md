# Release Checklist

## Prep
- [ ] Decide version and run `make release-prep VERSION=x.y.z`.
- [ ] Keep `VERSION` in strict `x.y.z` form (no leading `v`).
- [ ] Place release notes under `docs/release_notes/` (archive), not `dist/`.
- [ ] Ensure `VERSION` and `docs/README.md` point at the same current release notes file.
- [ ] Ensure `CHANGELOG.md` contains the current `- Release vx.y.z` entry and the current release notes title/version/tag fields match `VERSION`.
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
- [ ] `tools/release.sh` runs `release_check` + `release_audit` by default and verifies the generated tarball before continuing (use `--skip-checks` only for emergency/manual workflows).
- [ ] Optional manual build: `./tools/make_tarball.sh` (writes `dist/SHA256SUMS`, `dist/release_provenance.json`, and names the tarball from `VERSION` + current commit).
- [ ] (Optional) Sign tarball if using GPG.

## Verify
- [ ] Verify tarball: `linux-maint verify-release dist/Linux_Maint_ToolKit-*.tgz --sums dist/SHA256SUMS --manifest dist/release_provenance.json`.
- [ ] Confirm `verify-release` passes required tarball members (`install.sh`, CLI/lib payload, installed helpers, plugin index, matching release notes).
- [ ] Confirm `verify-release` passes provenance manifest checks (artifact name, SHA-256, version/tag, commit).
- [ ] Or run: `make verify-release` (runs release checks/audit + tarball verification).
- [ ] Smoke test install in a clean environment.

## Publish
- [ ] Tag release in git.
- [ ] Tag push triggers a draft release on GitHub (review/edit notes from `CHANGELOG.md` Unreleased).
- [ ] Upload tarball + checksums + provenance manifest.
- [ ] Confirm GitHub artifact attestations were generated for release tarball and RPM CI jobs.
- [ ] Publish release notes.
