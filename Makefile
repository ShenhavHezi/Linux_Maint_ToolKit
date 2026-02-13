# linux-maint Makefile (developer convenience)

SHELL := /usr/bin/env bash

.PHONY: help lint test release-tarball

help:
	@echo "Targets:"
	@echo "  make lint   - run ShellCheck (uses .shellcheckrc)"
	@echo "  make release-tarball - build offline release tarball (./dist)"
	@echo "  make test   - run repo test suite (contract + smoke)"

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

release-tarball:
	@./tools/make_tarball.sh
