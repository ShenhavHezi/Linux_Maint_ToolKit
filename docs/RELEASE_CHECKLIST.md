# Release Checklist

## Prep
- [ ] Decide version and run `make release-prep VERSION=x.y.z`.
- [ ] Place release notes under `docs/` (archive), not `dist/`.
- [ ] Run `./tools/release_check.sh`.
- [ ] Run `make lint` and `make test`.

## Breaking changes audit
- [ ] Confirm `docs/schemas/*.json` updated if output changed.
- [ ] Confirm `status_json_contract_version` was bumped if required.
- [ ] Confirm summary contract lines remain compatible.
- [ ] Note breaking changes explicitly in release notes.

## Build
- [ ] Build release tarball: `./tools/make_tarball.sh`.
- [ ] Generate checksums: `sha256sum dist/Linux_Maint_ToolKit-*.tgz > dist/SHA256SUMS`.
- [ ] (Optional) Sign tarball if using GPG.

## Verify
- [ ] Verify tarball: `linux-maint verify-release dist/Linux_Maint_ToolKit-*.tgz --sums dist/SHA256SUMS`.
- [ ] Or run: `make verify-release` (wraps `linux-maint verify-release`).
- [ ] Smoke test install in a clean environment.

## Publish
- [ ] Tag release in git.
- [ ] Tag push triggers a draft release on GitHub (review/edit notes from `CHANGELOG.md` Unreleased).
- [ ] Upload tarball + checksums.
- [ ] Publish release notes.
