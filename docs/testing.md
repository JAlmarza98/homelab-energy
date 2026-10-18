# Testing Guide

This document describes the testing strategy used by the Homelab Energy project.

---

# Goals

The testing framework has been designed with the following objectives:

* Simple
* Fast
* Dependency-free
* Easy to extend
* Easy to understand

Every module in the project should include its own test suite.

---

# Directory Structure

```text
tests/
├── logger/
│   ├── api_test.sh
│   └── handlers_test.sh
│
├── utils_test.sh
├── config_test.sh
├── bootstrap_test.sh
├── nut_test.sh
├── notify_test.sh
├── homelab_energy_test.sh
├── state_test.sh
├── shutdown_test.sh
└── metrics_test.sh
```

Each module owns its own tests.

As the project grows, modules may contain their own test directory if multiple test files are required.

---

# Running Tests

Run the complete test suite:

```bash
make test
```

Run formatting verification:

```bash
make format-check
```

Run ShellCheck:

```bash
make lint
```

Run every quality check:

```bash
make check
```

Recommended workflow before every commit:

```bash
make check
```

---

# Testing Principles

Every test should follow these principles.

## One Responsibility

Each test file should verify a single responsibility.

Good:

```text
logger/
    api_test.sh
    handlers_test.sh
```

Avoid:

```text
logger_test.sh
```

that mixes unrelated concerns.

---

## Independent Tests

Every test must configure its own environment.

Example:

```bash
LOGGER_LEVEL="${LOG_LEVEL_INFO}"
LOGGER_HANDLER_FILE=false
LOGGER_HANDLER_CONSOLE=true
```

A test must never depend on the execution order of another test.

---

## Arrange → Act → Assert

Every test should follow the same structure.

```text
Arrange
Act
Assert
```

Example:

```bash
LOGGER_LEVEL="${LOG_LEVEL_INFO}"

OUTPUT="$(log_info "Hello World")"

assert_true \
    "INFO appears" \
    grep -q "INFO" <<< "${OUTPUT}"
```

This makes every test easier to read and maintain.

---

## Test Public APIs

Whenever possible, tests should use the public API instead of internal functions.

Preferred:

```bash
log_info "System started"
```

Avoid:

```bash
_logger_log ...
```

Internal helpers may change without affecting the public interface.

---

## Keep Tests Small

Each test should verify one behaviour.

Good:

* Log level filtering
* File handler
* Console handler

Avoid very large test files that verify many unrelated behaviours.

---

# Assertions

The project provides a lightweight testing library.

Currently available assertions:

```bash
assert_true
assert_false
assert_equals
assert_success
```

New assertions should be generic and reusable across modules.

---

# Logger Tests

Logger tests are divided into responsibilities.

## API Tests

Verify:

* Public logging functions
* Log level filtering
* Output generation

Location:

```text
tests/logger/api_test.sh
```

---

## Handler Tests

Verify:

* Console handler
* File handler
* Journald handler (future)

Location:

```text
tests/logger/handlers_test.sh
```

---

## Formatter Tests (Future)

Future formatter tests will verify:

* Plain formatter
* Console formatter
* JSON formatter (Loki)

Location:

```text
tests/logger/formatters_test.sh
```

---

# Utilities Tests

Utilities are tested independently.

Current coverage includes:

* Command detection
* File existence
* Directory existence
* Directory creation
* Exit status helpers

Location:

```text
tests/utils_test.sh
```

---

# Adding a New Module

When creating a new module:

```
lib/
    example.sh

tests/
    example_test.sh
```

The test should cover:

* Public API
* Expected behaviour
* Failure cases

---

# Continuous Integration

The GitHub Actions workflow executes:

1. Format verification
2. ShellCheck
3. Test suite

A pull request should only be merged if all checks pass.

---

# Future Improvements

Planned additions include:

* Test coverage reporting
* Performance benchmarks
* Mock utilities
* Integration tests
* End-to-end tests

---

# Philosophy

The project values:

* Readability over cleverness
* Explicit behaviour over implicit behaviour
* Small, focused tests
* Deterministic execution
* Zero external runtime dependencies

Tests should document the expected behaviour of the project just as much as they verify it.
