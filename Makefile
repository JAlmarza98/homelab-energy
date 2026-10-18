SHELL := /bin/bash

.PHONY: help lint format format-check test check clean

help:
	@echo "Homelab Energy"
	@echo ""
	@echo "Available commands:"
	@echo "  make format"
	@echo "  make format-check"
	@echo "  make lint"
	@echo "  make test"
	@echo "  make check"

lint:
	find . -type f -name "*.sh" -print0 | xargs -0 -r shellcheck

format:
	find . -type f -name "*.sh" -print0 | xargs -0 -r shfmt -w -i 4

format-check:
	find . -type f -name "*.sh" -print0 | xargs -0 -r shfmt -d -i 4

test:
	@echo ""
	@echo "Running test suite..."
	@echo ""
	@status=0; \
	for f in $$(find tests -type f -name "*_test.sh"); do \
		bash "$$f" || status=1; \
	done; \
	exit $$status

check: format-check lint test

clean:
	rm -rf tests/tmp/*
