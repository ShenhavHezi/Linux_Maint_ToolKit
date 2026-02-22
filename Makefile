# linux-maint Makefile (developer convenience)

SHELL := /usr/bin/env bash

.PHONY: help lint test quick-check dev-check release-tarball make-tarball release install-githooks

help:
	@echo "Targets:"
	@echo "  make lint   - run ShellCheck (uses .shellcheckrc)"
	@echo "  make install-githooks - install executable hooks from .githooks/ into .git/hooks"
	@echo "  make release-tarball - build offline release tarball (./dist)"
	@echo "  make make-tarball - alias for release-tarball"
	@echo "  make release VERSION=x.y.z - bump version/changelog and tag (tools/release.sh)"
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

release-tarball:
	@./tools/make_tarball.sh

make-tarball: release-tarball

install-githooks:
	@./tools/install_githooks.sh

release:
	@if [ -z "$(VERSION)" ]; then echo "VERSION is required (e.g., make release VERSION=0.1.5)"; exit 2; fi
	@$(MAKE) lint
	@$(MAKE) test
	@./tools/release.sh "$(VERSION)" $(RELEASE_ARGS)
