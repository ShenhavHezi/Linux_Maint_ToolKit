# linux-maint Makefile (developer convenience)

SHELL := /usr/bin/env bash

.PHONY: help lint test dev-check release-tarball install-githooks

help:
	@echo "Targets:"
	@echo "  make lint   - run ShellCheck (uses .shellcheckrc)"
	@echo "  make install-githooks - install executable hooks from .githooks/ into .git/hooks"
	@echo "  make release-tarball - build offline release tarball (./dist)"
	@echo "  make test   - run repo test suite (contract + smoke)"
	@echo "  make dev-check - regenerate summarize + lint + smoke"

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


dev-check:
	@./tools/dev_check.sh

release-tarball:
	@./tools/make_tarball.sh

install-githooks:
	@./tools/install_githooks.sh
