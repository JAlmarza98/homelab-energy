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

## Isolation: never touch real hardware, config, state or network

This is `CLAUDE.md`'s "obligatory" rule, not just a style preference:
tests cannot have effects on real hardware. Three techniques cover
every current test:

**1. Stub the external command on a throwaway `PATH`.** Used for
`upsc` (`nut_test.sh`) and `curl` (`notify_test.sh`,
`homelab_energy_test.sh`): write a fake executable under
`tests/tmp/<suite>-bin/`, `chmod +x` it, and prepend that directory to
`PATH` for just the subprocess under test (`PATH="${STUB_BIN}:${PATH}"
bash -c '...'`). The stub can echo canned output, log its invocation to
a file for later assertions, or exit non-zero to simulate an unreachable
host — never the real binary, ever.

**2. Override the directories/files a module reads or writes.**
`config.sh`, `state.sh` and `metrics.sh` all read their paths from
environment variables with a `${VAR:-default}` fallback
(`CONFIG_DIR`, `STATE_DIR`, `METRICS_FILE`, `SECRETS_CONFIG_LOCAL`,
`SECRETS_CONFIG_SYSTEM`) specifically so tests can point them at
`tests/tmp/...` instead of the real `config/`/`state/` or a
production-only path like `/var/lib/node_exporter/...`. Any new module
that touches disk should take the same shape.

**3. Run the subprocess in its own shell, not the test script's own.**
Both techniques above are usually combined with `bash -c '...'` (or
invoking a real `bin/*` script as a subprocess) rather than sourcing the
module directly into the test's own shell — this keeps `set -e`,
environment variables and sourced libraries from one test case leaking
into the next, and lets a single test assert on a process's exit code
without the whole suite dying under `set -e` if that command is meant to
fail (`assert_false`/`assert_success` already run the command in a
context where its exit status doesn't trigger `errexit`).

A quoting note for technique 3: write `source "${PROJECT_ROOT}/lib/x.sh"`
**inside** the single-quoted `bash -c` script (letting the *inner* shell
expand it from an exported `PROJECT_ROOT="${PROJECT_ROOT}"` prefix),
not `source "'"${PROJECT_ROOT}"'"/lib/x.sh"` (breaking out of the
quotes to let the *outer* shell pre-bake the path). The second form
still works, but ShellCheck flags the exported `PROJECT_ROOT=` prefix as
unused (SC2097/SC2098) because, from a single file's point of view, it
is — the library that actually reads it at runtime is invisible to
ShellCheck. Prefer the first form; it's also the one `config_test.sh`
already uses for `CONFIG_DIR`.

Always clean up fixtures at the end of the test file (`rm -rf
tests/tmp/<suite>-*`), not just on `make clean` — a left-over stub
`PATH` or state dir from a previous run must never affect the next one.

---

# Assertions

The project provides a lightweight testing library (`lib/test.sh`).

## Suite lifecycle

```bash
test_init "Suite Name"    # prints the suite header; call once, first
test_summary               # prints totals; returns 1 if anything failed —
                            # this is what makes make test's loop fail
```

## Assertions

```bash
assert_success NAME COMMAND...   # passes if COMMAND exits 0
assert_true NAME COMMAND...      # alias for assert_success
assert_false NAME COMMAND...     # passes if COMMAND exits non-zero
assert_equals NAME EXPECTED ACTUAL
assert_command COMMAND_NAME      # passes if COMMAND_NAME exists on PATH
```

`assert_false` existed from the start but was a literal copy-paste of
`assert_success` (v0.1.1 bug #3) — it always passed, regardless of
whether the command actually failed. Any new assertion should have at
least one test exercising both its PASS and FAIL path, specifically
because that bug shipped silently for a while.

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

# Bootstrap Tests

Verify:

* `bootstrap` runs end to end against the **real** `config/` (not an
  isolated fixture — this is the one suite that intentionally exercises
  the real site config, as a smoke test that `load_config` +
  `logger_set_level` actually wire together).
* `config_get` after `bootstrap` returns a real site value (`UPS_NAME`).
* `LOG_LEVEL` from `energy.conf` ends up as the matching `LOGGER_LEVEL`.

Location:

```text
tests/bootstrap_test.sh
```

---

# Config Tests

Verify:

* Layering order: `defaults.conf` → `energy.conf` → `hosts/<hostname>.conf`
  → secrets, each overriding the last, using a throwaway `CONFIG_DIR`
  fixture (never the real `config/`).
* `config_get`/`config_exists` for both defined and unknown keys.
* Validation failures: a non-integer `SHUTDOWN_DELAY`, a missing
  `defaults.conf`.
* The secrets permission check: a `chmod 600` secrets file loads, a
  `chmod 644` one is refused — via overridable `SECRETS_CONFIG_LOCAL`.

Location:

```text
tests/config_test.sh
```

---

# NUT Tests

Verify, against a **stubbed `upsc`** on a throwaway `PATH` (never the
real NUT server):

* `nut_get_status`/`nut_get_charge`/`nut_get_runtime`/`nut_get_voltage`/
  `nut_get_load` read the right `upsc` variable.
* `nut_is_online`/`nut_is_on_battery` react correctly to `ups.status`
  values like `OL` and `OB LB`.
* An unreachable UPS (stub exits non-zero) makes `nut_is_online` fail
  rather than silently reporting online.

Location:

```text
tests/nut_test.sh
```

---

# Notify Tests

Verify, against a **stubbed `curl`** on a throwaway `PATH` (never a real
HTTP request):

* Disabled notifications (`NOTIFICATIONS_ENABLED=false`) and a missing
  `NTFY_TOPIC` both skip `curl` entirely.
* An enabled, configured send calls `curl` with the message and the
  right `Priority` header.
* `metrics:notify_sent`/`metrics:notify_failed` increment correctly
  depending on the stub's exit code.
* **Fail-safe, under `set -e`**: a failing `curl` (stub exits 1) never
  aborts the caller — this specifically runs the assertion inside a
  `bash -c 'set -Eeuo pipefail; ...'` subshell, the same strict mode
  `bootstrap.sh` uses, to prove it for real rather than assuming it.

Location:

```text
tests/notify_test.sh
```

---

# State Tests

Verify, against an isolated `STATE_DIR` (never the real `state/`):

* `state_load` bootstraps an empty `{}` state file if none exists.
* `state_get`/`state_set`/`state_exists`/`state_delete` round-trip on
  the in-memory copy.
* `state_save` writes valid JSON, and a fresh `state_load` reads back
  what a previous `state_save` persisted.
* Lock contention: a background process holding the `flock` makes a
  concurrent `state_save` fail (with a short `STATE_LOCK_WAIT`, never
  `-w 0` — see `docs/architecture.md`'s Platform Compatibility section
  for why), and it succeeds once the lock is released.

Location:

```text
tests/state_test.sh
```

---

# Shutdown Tests

Verify, entirely with local marker files and exit codes (never a real
host):

* `shutdown_start` is idempotent — a second call while `in_progress`
  doesn't reset anything.
* `SHUTDOWN_DRY_RUN` (default `true`): `shutdown_execute` reports
  success without running the command at all.
* Real execution (`SHUTDOWN_DRY_RUN=false`): success, failure and
  timeout each mark the right status (`completed`/`failed`), and the
  timeout actually fires before the command would otherwise finish
  (`sleep 5` with a 1s timeout, asserted to take ~1s, not ~5s).
* A `completed` host is skipped on retry; a `failed` one is retried
  (idempotency is deliberately asymmetric between these two states —
  see `shutdown.sh`'s API doc).
* `shutdown_cancel` makes a subsequent `shutdown_execute` refuse to run.

Location:

```text
tests/shutdown_test.sh
```

---

# Metrics Tests

Verify, against isolated `STATE_DIR`/`METRICS_FILE`:

* `metrics_update` sets a value; `metrics_increment` starts at `1` from
  unset and adds `1` on each subsequent call.
* `metrics_collect`'s output includes the last-event gauge with its
  `event` label, the notification counters, and a `shutdown.sh` host's
  status mapped to the right numeric code.
* `metrics_export` writes valid Prometheus text (checked for `# TYPE`
  lines) and leaves no leftover temp file behind.

Location:

```text
tests/metrics_test.sh
```

---

# bin/homelab-energy Tests

The one suite that exercises a real executable as a subprocess (`bin/
homelab-energy` and `bin/homelab-energy-cmdscript`), with every external
effect isolated: a stubbed `curl`, and `CONFIG_DIR`/`STATE_DIR`/
`METRICS_FILE`/`SECRETS_CONFIG_LOCAL` all pointed at `tests/tmp/`.

Verify:

* Missing arguments / missing event name both exit non-zero with a
  usage message.
* `ONBATT`/`ONLINE`/`LOWBATT` each notify with the expected text, and
  get recorded as `metrics:last_event` in `state/state.json`, and show
  up in the exported metrics textfile.
* An unrecognised event name still exits 0 (an unknown NUT event must
  never make the hook itself fail) and sends no notification.
* `homelab-energy-cmdscript` correctly forwards its single argument
  into `homelab-energy event <name>`.

Location:

```text
tests/homelab_energy_test.sh
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
* Zero effect on real hardware, network, config or state — trusted local
  tools (`jq`, `flock`) run for real in tests; anything that would touch
  a UPS, a remote host or the network (`upsc`, `curl`, `ssh`) is always
  stubbed

Tests should document the expected behaviour of the project just as much as they verify it.
