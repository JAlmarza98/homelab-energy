# Architecture

This document describes the architectural principles of the Homelab Energy project.

The goal is to keep the codebase simple, modular, maintainable and easy to extend over time.

---

# Design Principles

The project follows a few fundamental principles.

## Single Responsibility

Each module is responsible for one thing only.

Examples:

```text id="awpivn"
logger.sh
    Logging

config.sh
    Configuration loading

state.sh
    Persistent state

nut.sh
    UPS communication

proxmox.sh
    Proxmox integration
```

Modules should never grow into "utility collections".

---

## Explicit Over Implicit

Code should be easy to understand without hidden behaviour.

Prefer:

```bash id="hk3b7v"
logger_enable_file
```

over directly modifying global variables in multiple places.

Avoid side effects whenever possible.

---

## Readability First

The project favours readable code over clever code.

Good code should be understandable after several months without additional explanation.

---

## Simplicity

Avoid unnecessary abstractions.

A new abstraction should only be introduced when there are at least two or three real implementations that justify it.

---

# Project Structure

```text id="br7lsd"
bin/
config/
docs/
lib/
logs/
services/
state/
templates/
tests/
```

Each directory has a single purpose.

---

# Module Structure

Every module should follow the same layout.

```text id="svq65q"
Configuration

Public API

Core

Utilities

Formatters (optional)

Handlers (optional)
```

Not every module requires every section.

Sections should only exist when they provide value.

---

# Public vs Private API

Public functions:

```text id="rfm8xg"
log_info
config_load
state_save
nut_connect
```

Private helpers:

```text id="jlwm7y"
_logger_log
_config_parse
_state_read
_nut_query
```

Private functions always start with a single underscore.

Only public functions should be used by other modules.

---

# Module Independence

Modules should remain independent.

A module should never source another module directly.

Preferred architecture:

```text id="mwghob"
bootstrap.sh

│

├── logger.sh

├── config.sh

├── state.sh

├── nut.sh
```

A single bootstrap process will initialise the framework and load dependencies.

This avoids circular dependencies and improves reusability.

---

# Logging Architecture

The logger follows a layered architecture.

```text id="zkuqst"
Public API

↓

Core

↓

Dispatcher

↓

Handlers

↓

Formatters

↓

Output
```

Example flow:

```text id="0c8gdf"
log_info()

↓

_logger_log()

↓

_logger_dispatch()

↓

Console Handler

↓

Console Formatter

↓

stdout
```

Handlers are responsible for writing.

Formatters are responsible for representing data.

This separation allows future outputs (JSON, Loki, Journald) without modifying the logger core.

---

# Testing Architecture

Tests are organised by module.

```text id="l4p98o"
tests/

logger/
utils/
config/
state/
```

Each test file should verify one responsibility only.

Tests should:

* be independent
* be deterministic
* avoid shared state
* use the public API whenever possible

---

# Coding Standards

## Function Order

Modules should generally follow this order.

```text id="d7dsgx"
Configuration

Public API

Core

Utilities

Formatters

Handlers
```

This matches the execution flow and improves readability.

---

## Naming

Public functions:

```text id="2v7srd"
log_info
state_save
config_load
```

Private helpers:

```text id="gqyxm0"
_logger_log
_state_write
_config_read
```

Global configuration:

```text id="zjlwmq"
LOGGER_LEVEL
LOGGER_FILE_PATH
```

Constants:

```text id="kizfzb"
LOG_LEVEL_INFO
LOGGER_COLOR_INFO
```

---

# Error Handling

Modules should:

* return meaningful exit codes
* avoid silent failures
* validate inputs
* fail fast whenever appropriate

Unexpected situations should be logged whenever possible.

---

# Dependencies

The framework aims to minimise runtime dependencies.

Current development tools include:

* Bash
* ShellCheck
* shfmt
* Make

Runtime should remain dependency-light whenever possible.

---

# Scalability

The architecture is designed to grow incrementally.

Future modules include:

```text id="ljm5d3"
bootstrap.sh
config.sh
state.sh
nut.sh
proxmox.sh
grafana.sh
notifications.sh
scheduler.sh
```

Each new module should follow the same architectural principles.

---

# Philosophy

The project is built around a few core ideas.

* One responsibility per module.
* Small and reusable functions.
* Clear public APIs.
* Minimal coupling.
* Explicit behaviour.
* Testability.
* Incremental evolution.

The architecture intentionally avoids unnecessary complexity while leaving room for future growth.

Every architectural decision should favour long-term maintainability over short-term convenience.
