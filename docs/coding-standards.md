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

**"Executable script" excludes library modules.** `lib/*.sh` files
(except `bootstrap.sh`) are sourced, never executed directly, and must
**not** set `set -Eeuo pipefail` or source another library — only
`lib/bootstrap.sh` and the real executables (`bin/*`, `tests/*_test.sh`)
do that. A library that sets it anyway was v0.1.1 bug #5: sourcing two
such libraries into the same shell can silently change the calling
script's error-handling behaviour out from under it. See
`docs/architecture.md`'s Module Independence section for the full
source order.

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

loaded through `load_config`/`config_get`, from layered files (later
overrides earlier):

```text
config/defaults.conf              (required; safe baseline)
config/energy.conf                (this site's real values)
config/hosts/<hostname>.conf      (per-host overrides)
.env  or  /etc/homelab-energy/secrets.env   (secrets; chmod 600 enforced)
```

See `docs/api.md`'s `config.sh` section for the full key reference and
why files are parsed, never `source`d.

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

Dependencies must be validated before the code that needs them runs —
not necessarily centrally at startup; a check right at the point of use
(e.g. `state.sh`'s `_state_require_jq`) is preferred over a single
upfront module when most runs don't need most dependencies. See
`docs/api.md`'s "dependencies.sh — superseded" section for why.

Examples:

* `jq`, `flock` — `state.sh`
* `upsc` — `nut.sh`
* `curl` — `notify.sh`

Do not assume external commands exist. Do not assume a GNU-only flag
exists either — development happens on macOS, where the default `date`,
`stat` and `timeout` differ from Raspberry Pi's. See
`docs/architecture.md`'s "Platform Compatibility" section before adding
a new one.

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

tests/logger/api_test.sh
tests/logger/handlers_test.sh

state.sh

↓

tests/state_test.sh
```

A module gets its own `tests/<module>/` subdirectory only once a single
flat `tests/<module>_test.sh` would mix unrelated responsibilities
(`logger.sh` is the current example); otherwise one flat file per
module is the default. See `docs/testing.md` for the full current list.

Tests should be executable independently, and must never touch real
hardware, the real `config/`/`state/` directories, or the network — see
`docs/testing.md`'s isolation patterns (stubbed `PATH`, overridden
`CONFIG_DIR`/`STATE_DIR`/`METRICS_FILE`).

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
