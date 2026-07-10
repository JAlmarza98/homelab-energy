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
	find . -type f -name "*.sh" -print0 | xargs -0 -r shfmt -d

test:
	@echo ""
	@echo "Running test suite..."
	@echo ""
	@find tests -type f -name "*_test.sh" -exec bash {} \;

check: format-check lint test

clean:
	rm -rf tests/tmp/*
