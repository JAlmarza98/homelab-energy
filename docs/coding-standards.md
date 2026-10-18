# Coding Standards

This document defines the coding conventions used throughout the Homelab Energy project.

The objective is consistency, readability and maintainability.

These rules apply to every module in the project.

---

# General Principles

The project follows five fundamental principles.

* Keep It Simple (KISS)
* Don't Repeat Yourself (DRY)
* Single Responsibility Principle (SRP)
* Fail Fast
* Explicit is Better Than Implicit

Whenever two possible implementations exist, choose the simplest one that satisfies the requirements.

---

# File Structure

Every shell script must follow the same structure.

```bash
#!/usr/bin/env bash

set -Eeuo pipefail

################################################################################
# Constants
################################################################################

################################################################################
# Private Functions
################################################################################

################################################################################
# Public Functions
################################################################################
```

Files should always appear in this order.

---

# File Header

Every executable script starts with:

```bash
#!/usr/bin/env bash

set -Eeuo pipefail
```

The project always uses Bash.

Do not use `/bin/sh`.

---

# Module Responsibilities

Each file must have exactly one responsibility.

Good examples:

* logger.sh
* config.sh
* state.sh
* nut.sh

Bad examples:

* utils.sh containing UPS functions
* logger.sh reading configuration files

---

# Naming Conventions

## Variables

Global variables use uppercase.

Example:

```bash
PROJECT_ROOT

CONFIG_DIR

STATE_DIR

LOG_LEVEL
```

---

Local variables use lowercase.

Example:

```bash
local battery_charge

local runtime

local json
```

---

Boolean variables should read naturally.

Good:

```bash
ENABLE_PROMETHEUS

LOGGER_CONSOLE

SHUTDOWN_ENABLED
```

Avoid names like:

```bash
FLAG

VALUE

OPTION
```

---

# Constants

Constants must always be declared as readonly.

Example:

```bash
readonly PROJECT_NAME="homelab-energy"

readonly VERSION="0.1.0-dev"
```

---

# Functions

Function names use snake_case.

Good:

```bash
load_config

log_info

state_get

state_set

nut_get_status
```

Bad:

```bash
LoadConfig

GetUPS

test

run
```

---

# Private Functions

Private functions start with "_".

Example:

```bash
_format_message()

_write_console()

_should_log()
```

Only public functions may be called from outside the module.

---

# Function Size

Functions should be short.

As a general guideline:

* Prefer less than 30 lines.
* If a function becomes difficult to understand, split it.

---

# Comments

Comments should explain **why**, not **what**.

Good:

```bash
# Retry because some USB devices need a few seconds after reconnecting.
```

Bad:

```bash
# Increment counter

counter=$((counter + 1))
```

The code should explain what it does.

Comments explain why.

---

# Error Handling

Never ignore errors.

Prefer:

```bash
if ! load_config; then
    log_error "Unable to load configuration."
    exit 1
fi
```

Avoid:

```bash
load_config || true
```

Unless the failure is explicitly expected.

---

# Exit Codes

Use standard exit codes whenever possible.

0

Success

1

Generic error

2

Invalid arguments

Higher values may be used for project-specific situations.

---

# Logging

Never use:

```bash
echo
```

for runtime messages.

Always use the logger module.

Example:

```bash
log_info "Configuration loaded."

log_warn "UPS running on battery."

log_error "Unable to contact Proxmox."
```

Console output should remain consistent throughout the project.

---

# Configuration

Never hardcode configuration values.

Bad:

```bash
UPS_NAME="apc"
```

Good:

```bash
UPS_NAME
```

loaded from:

```text
config/energy.conf
```

---

# State Management

Only the state module may read or modify files inside:

```text
state/
```

Other modules must use:

```bash
state_get

state_set
```

This guarantees a single source of truth.

---

# Dependencies

Dependencies must be validated during startup.

Examples:

* jq
* upsc
* curl

Do not assume external commands exist.

---

# Paths

Always use absolute paths generated from PROJECT_ROOT.

Good:

```bash
"${PROJECT_ROOT}/config"
```

Avoid:

```bash
../config
```

Relative paths become unreliable when scripts are executed from different locations.

---

# Quoting

Always quote variables unless word splitting is explicitly required.

Good:

```bash
"${PROJECT_ROOT}"

"${UPS_NAME}"
```

Avoid:

```bash
$PROJECT_ROOT
```

---

# Command Substitution

Always prefer:

```bash
value="$(command)"
```

Instead of:

```bash
value=`command`
```

---

# Tests

Every module should have an associated test.

Example:

```text
logger.sh

↓

tests/test-logger.sh
```

Tests should be executable independently.

---

# Formatting

Formatting is enforced using:

* shfmt
* ShellCheck

Every commit should pass formatting and linting.

---

# Git Commits

Commit messages follow Conventional Commits.

Examples:

```text
feat: add NUT monitoring module

fix: handle missing UPS connection

docs: update architecture

refactor: simplify logger

test: add state manager tests
```

---

# Documentation

Every public module should be documented.

Architecture decisions should be recorded as ADR documents.

Complex behaviour should be documented before implementation.

---

# Design Philosophy

The codebase should always feel as if it had been written by a single developer.

Consistency is preferred over personal preference.

Whenever a new feature is implemented, existing conventions should be followed instead of introducing new patterns.

Long-term maintainability is considered more important than short-term convenience.
