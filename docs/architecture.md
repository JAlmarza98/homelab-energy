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
    UPS communication (read-only)

notify.sh
    Notifications (Telegram)

shutdown.sh
    Shutdown of non-NUT hosts

metrics.sh
    Prometheus textfile metrics

proxmox.sh
    Proxmox integration (future)
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
bin/            entry points (homelab-energy, homelab-energy-cmdscript)
config/         defaults.conf, energy.conf, hosts/<hostname>.conf, secrets.env.example
docs/
lib/            modules sourced via bootstrap.sh
logs/           created on demand by logger.sh (LOGGER_HANDLER_FILE); gitignored
services/       reserved for real systemd units, once something installs them
state/          created on demand by state.sh (state.json, state.lock); gitignored
templates/      deployment examples (never applied automatically — see templates/*.example)
tests/
```

Each directory has a single purpose. `logs/`, `state/` and (so far)
`services/` don't exist until something needs them: `logs/` and `state/`
are created at runtime by `ensure_directory` the first time a module
writes to them, and `services/` is aspirational until a real install
mechanism needs it — deployment examples currently live in `templates/`
instead, each suffixed `.example` precisely so it's never mistaken for
live config.

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

├── utils.sh

├── logger.sh

├── config.sh

├── nut.sh

├── notify.sh

├── state.sh

├── shutdown.sh

├── metrics.sh
```

This is the real, current source order in `lib/bootstrap.sh` — not just a
preference. `bin/homelab-energy` sources only `bootstrap.sh`; every other
public function (`log_*`, `config_get`, `nut_get_*`, `notify_*`,
`state_*`, `shutdown_*`, `metrics_*`) becomes available transitively.

A single bootstrap process initialises the framework and loads every
library. This avoids circular dependencies and improves reusability.

Modules still call each other's public functions directly without
sourcing one another — e.g. `notify.sh` calls `log_warn` and
`metrics_increment`, `shutdown.sh` and `metrics.sh` call `state_get`/
`state_set`. This only works because `bootstrap.sh` already sourced
all of them into the same shell; a module sourced standalone (as tests
often do, for isolation) must bring in whatever it actually calls. See
`docs/testing.md`'s isolation notes for the pattern.

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

Tests are organised by module: one `<module>_test.sh` per module, flat
under `tests/`, except `logger.sh` which has enough responsibilities
(API, handlers) to earn its own `tests/logger/` subdirectory. See
`docs/testing.md` for the full current list and the per-suite breakdown.

```text id="l4p98o"
tests/

logger/
    api_test.sh
    handlers_test.sh
utils_test.sh
config_test.sh
state_test.sh
```

A module only grows its own subdirectory once a single flat `_test.sh`
would mix unrelated responsibilities — don't create one preemptively.

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

Current runtime dependencies, and exactly when each is required:

* `jq` and `flock` — `state.sh`, every call (`metrics.sh` depends on
  `state.sh`, so it needs both too). Checked on demand
  (`_state_require_jq`), not at `bootstrap()` time.
* `curl` — `notify.sh`, only once a notification is actually about to be
  sent (`NOTIFICATIONS_ENABLED=true` and `TELEGRAM_BOT_TOKEN`/
  `TELEGRAM_CHAT_ID` set). A disabled install never needs it.
* `upsc` — `nut.sh`, every call. No explicit check: missing `upsc`
  surfaces as the same failure as an unreachable UPS.

`bash`, `date`, `mkdir`, `hostname` are checked unconditionally by
`bootstrap()` (`require_command`, from `utils.sh`) since every run needs
them regardless of subcommand. See `docs/api.md`'s "dependencies.sh —
superseded" section for why there's no single centralised dependency
module.

Runtime should remain dependency-light whenever possible.

---

# Platform Compatibility

Development happens on a Mac (CLAUDE.md); production runs on Raspberry Pi
(Debian/Raspbian). Several real differences between macOS and Linux have
already shaped the code, not just the docs — anyone adding new library
code should check against this list before reaching for a GNU-only flag
or a bash 4+ feature.

## macOS's default `/bin/bash` is 3.2, not 4+

Raspberry Pi's bash is 5.x; macOS ships 3.2 (Apple hasn't updated it since
the GPLv3 switch) and most developers won't have installed a newer one
just for this project. Code that needs to run identically in `make check`
on both:

* **No `declare -A`** (associative arrays, bash 4.0+). `config.sh` uses
  dynamic `printf -v "${key}" '%s' "${value}"` assignment of plain global
  variables instead, read back via indirect expansion (`${!key}`).
* **No `exec {fd}>file`** (bash 4.1+ auto-allocated file descriptor).
  `state.sh` uses a fixed `STATE_LOCK_FD=200` via `eval "exec 200>…"`.

## GNU coreutils vs. BSD/macOS userland

* **`date`**: GNU's `date --iso-8601=seconds` doesn't exist on macOS's
  BSD `date`. `utils.sh`'s `timestamp_iso8601` uses the portable
  `date '+%Y-%m-%dT%H:%M:%S%z'` instead.
* **`timeout`**: GNU coreutils' `timeout` command isn't on macOS at all
  (not even as `gtimeout` without installing `coreutils` via Homebrew).
  `shutdown.sh`'s `_shutdown_run_with_timeout` implements it with a
  background job + a watchdog subshell that `kill`s it after N seconds,
  no external dependency either way.
* **`stat`**: GNU `stat -c '%a'` vs. BSD `stat -f '%Lp'` for a file's
  octal permissions. `config.sh`'s `_config_mode` tries the GNU form
  first, falling back to the BSD one.

## `flock` doesn't ship with macOS at all

`state.sh` needs it. The Homebrew formula (`brew install flock`, from
discoteq/flock) implements a close-enough-for-this-project subset of the
same CLI as util-linux's `flock` on Debian/Raspbian — but **`-w 0` means
something different between them** (one treats it as "don't wait", the
other rejects it outright), so `state.sh` and its tests always pass a
positive wait value and never rely on `-w 0`'s exact semantics.

## Why this matters architecturally, not just as trivia

`CLAUDE.md`'s workflow section says development happens on the Mac and
`make check` must pass there before anything reaches RP-node2. A module
that only works on Linux would make that workflow a lie. Every new
library function that shells out to an external command should ask: does
this flag/behaviour exist identically on both BSD and GNU userland, and
on bash 3.2 as well as 5.x? If not, find (or write) the portable
equivalent, the way the examples above did — don't just add a `brew
install` line and move on, since that still leaves the *behavioural*
difference (`-w 0`, GNU-only flags) for someone to hit later.

---

# Scalability

The architecture is designed to grow incrementally.

Delivered modules (see `docs/api.md` for each one's full public API):

```text id="ljm5d3"
bootstrap.sh
utils.sh
logger.sh
config.sh
nut.sh
notify.sh
state.sh
shutdown.sh
metrics.sh
```

Still future:

```text id="ljm5d4"
proxmox.sh        # v0.8.0-adjacent; no current consumer
grafana.sh        # dashboards are provisioned in Grafana itself, via the
                   # templates/ stack — may never need to be a module
scheduler.sh
```

`dependencies.sh` was planned but superseded by per-module checks instead
(`docs/api.md`) — it's not "future", it's a deliberately different design.

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
