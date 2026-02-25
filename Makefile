# linux-maint Makefile (developer convenience)

SHELL := /usr/bin/env bash

.PHONY: help lint test quick-check dev-check docs-check release-tarball make-tarball release release-prep release-check verify-release install-githooks

help:
	@echo "Targets:"
	@echo "  make lint   - run ShellCheck (uses .shellcheckrc)"
	@echo "  make install-githooks - install executable hooks from .githooks/ into .git/hooks"
	@echo "  make release-tarball - build offline release tarball (./dist)"
	@echo "  make make-tarball - alias for release-tarball"
	@echo "  make release VERSION=x.y.z - bump version/changelog, tag, and build tarball (tools/release.sh)"
	@echo "  make release-prep VERSION=x.y.z - bump version/changelog and draft notes (tools/release_prep.sh)"
	@echo "  make release-check - validate docs/schemas/release notes (tools/release_check.sh)"
	@echo "  make verify-release - verify tarball checksums (linux-maint verify-release)"
	@echo "  make docs-check - validate internal markdown links"
	@echo "  make test   - run repo test suite (contract + smoke)"
	@echo "  make quick-check - run fast contract/lint checks"
	@echo "  make dev-check - run lint + smoke"

lint:
	@./tools/shellcheck_wrapper.sh -x run_full_health_monitor.sh
	@./tools/shellcheck_wrapper.sh -x lib/linux_maint.sh
	@./tools/shellcheck_wrapper.sh -x bin/linux-maint
	@./tools/shellcheck_wrapper.sh -x monitors/*.sh
	@./tools/shellcheck_wrapper.sh -x tests/*.sh
	@./tools/shellcheck_wrapper.sh -x tools/*.sh

# Keep test target aligned with CI (unprivileged)
# NOTE: sudo-gated tests may be skipped depending on environment.

test:
	@mkdir -p .logs
	@./tests/summary_contract.sh
	@./tests/summary_contract_lint.sh
	@./tests/smoke.sh


quick-check:
	@./tools/quick_check.sh

dev-check:
	@./tools/dev_check.sh

docs-check:
	@./tools/docs_link_check.sh

release-tarball:
	@./tools/make_tarball.sh

make-tarball: release-tarball

release-check:
	@./tools/release_check.sh

verify-release:
	@./bin/linux-maint verify-release dist/Linux_Maint_ToolKit-*.tgz --sums dist/SHA256SUMS

install-githooks:
	@./tools/install_githooks.sh

release:
	@if [ -z "$(VERSION)" ]; then echo "VERSION is required (e.g., make release VERSION=0.1.5)"; exit 2; fi
	@$(MAKE) lint
	@$(MAKE) test
	@./tools/release.sh "$(VERSION)" --with-tarball $(RELEASE_ARGS)

release-prep:
	@if [ -z "$(VERSION)" ]; then echo "VERSION is required (e.g., make release-prep VERSION=0.1.5)"; exit 2; fi
	@./tools/release_prep.sh "$(VERSION)" $(RELEASE_ARGS)
