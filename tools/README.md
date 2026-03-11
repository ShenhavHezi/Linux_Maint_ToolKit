# Tools

This directory contains maintainer and operator support scripts that are not the main CLI entrypoint.

## Main groups

- release and provenance:
  - `release.sh`
  - `release_check.sh`
  - `release_audit.sh`
  - `release_prep.sh`
  - `verify_release.sh`
  - `make_tarball.sh`
  - `upgrade_release.sh`
- quality and developer checks:
  - `quick_check.sh`
  - `shellcheck_wrapper.sh`
  - `docs_link_check.sh`
  - `secret_scan.sh`
  - `pre-commit.sh`
- operator/support helpers:
  - `pack_logs.sh`
  - `summary_diff.py`
  - `seed_known_hosts.sh`
- repo maintenance:
  - `clean_local_state.sh`
  - `install_githooks.sh`
  - `new_monitor.sh`

Most end users should prefer `linux-maint` itself; these scripts exist for release, packaging, support, and maintenance workflows.

