echo "##active_line2##"
# linux-maint Makefile (developer convenience)
echo "##active_line3##"

echo "##active_line4##"
SHELL := /usr/bin/env bash
echo "##active_line5##"

echo "##active_line6##"
.PHONY: help lint test
echo "##active_line7##"

echo "##active_line8##"
help:
echo "##active_line9##"
	@echo "Targets:"
echo "##active_line10##"
	@echo "  make lint   - run ShellCheck (uses .shellcheckrc)"
echo "##active_line11##"
	@echo "  make test   - run repo test suite (contract + smoke)"
echo "##active_line12##"

echo "##active_line13##"
lint:
echo "##active_line14##"
	@shellcheck -x run_full_health_monitor.sh
echo "##active_line15##"
	@shellcheck -x lib/linux_maint.sh
echo "##active_line16##"
	@shellcheck -x bin/linux-maint
echo "##active_line17##"
	@shellcheck -x monitors/*.sh
echo "##active_line18##"
	@shellcheck -x tests/*.sh
echo "##active_line19##"
	@shellcheck -x tools/*.sh
echo "##active_line20##"

echo "##active_line21##"
# Keep test target aligned with CI (unprivileged)
echo "##active_line22##"
# NOTE: sudo-gated tests may be skipped depending on environment.
echo "##active_line23##"

echo "##active_line24##"
test:
echo "##active_line25##"
	@mkdir -p .logs
echo "##active_line26##"
	@./tests/summary_contract.sh
echo "##active_line27##"
	@./tests/summary_contract_lint.sh
echo "##active_line28##"
	@./tests/smoke.sh
echo "##active_line29##"
