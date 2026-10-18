# Internal API

This document defines the public interfaces exposed by every project module.

Modules communicate only through their public functions.

Private functions (prefixed with `_`) must never be called outside their own module.

---

# Design Principles

Every module should:

* Have a single responsibility.
* Expose a minimal public API.
* Hide implementation details.
* Avoid side effects whenever possible.

Modules communicate through function calls rather than shared implementation.

---

# bootstrap.sh

## Purpose

Initialize the project runtime.

Every executable script should source this module before using any other library.

## Public API

```bash
bootstrap
```

### Responsibilities

* Detect project root.
* Export common paths.
* Load project libraries.
* Validate runtime environment.
* Load configuration.
* Initialize logging.

---

# bin/homelab-energy

## Purpose

The only entry point into the project at runtime. Sources `bootstrap.sh`,
calls `bootstrap`, then dispatches a subcommand.

## Usage

```text
homelab-energy event <NUT_EVENT_NAME>
```

### Behaviour

* `event ONBATT` / `event ONLINE` / `event LOWBATT`: log and notify
  (`notify_warning`/`notify_success`/`notify_error`). NUT (`upsmon`) already
  decided the event happened; this never makes a shutdown decision.
* Any other event name: logged via `log_warn`, no notification, exits 0 —
  an unrecognised event must never make the hook fail.
* Missing/unknown subcommand: usage message on stderr, exit 2.
* Records `last_event`/`last_event_at` via `metrics_update` and exports
  metrics (`metrics_export`) after every `event` call. A metrics export
  failure (e.g. the textfile collector directory doesn't exist) is logged
  via `log_warn` and never fails the hook.

## bin/homelab-energy-cmdscript

`upssched`'s `CMDSCRIPT` directive calls a single executable with exactly
one argument (the message name from an `AT ... EXECUTE` rule); it cannot
embed `event` as a literal extra argument. This shim exists only to adapt
that one-argument call into `homelab-energy event <name>`. See
`templates/upssched.conf.example` for the `upssched.conf` wiring.

---

# logger.sh

## Purpose

Provide a consistent logging interface.

## Public API

```bash
log_debug MESSAGE

log_info MESSAGE

log_success MESSAGE

log_warn MESSAGE

log_error MESSAGE
```

### Behaviour

* Adds timestamp.
* Adds log level.
* Writes to configured outputs.
* Honors configured log level.

---

# config.sh

## Purpose

Load and validate project configuration.

## Public API

```bash
load_config

reload_config

config_get VARIABLE

config_exists VARIABLE
```

### Behaviour

Configuration files are loaded only through this module.

Other modules should never source configuration files directly.

---

# state.sh

## Purpose

Maintain the centralized runtime state.

## Public API

```bash
state_get KEY

state_set KEY VALUE

state_delete KEY

state_exists KEY

state_load

state_save
```

### Behaviour

The state module owns every file inside the `state/` directory.

No other module should modify state files directly.

* Backed by a single `state/state.json`, read into the in-memory
  `STATE_JSON` string by `state_load`. `state_get`/`state_set`/`state_delete`/
  `state_exists` only touch that in-memory copy via `jq` — call `state_load`
  first, and `state_save` to persist.
* `state_save` writes to a temp file and `mv`s it into place (atomic), and
  both `state_load` and `state_save` hold an exclusive `flock` on
  `state/state.lock` while they touch disk.
* Requires `jq` and `flock`. Last-writer-wins: this does not merge concurrent
  changes, it only keeps a single write from corrupting the file.

---

# utils.sh

## Purpose

Provide reusable helper functions.

## Planned Public API

```bash
require_command COMMAND

require_file FILE

require_directory DIRECTORY

retry COMMAND

timestamp_now

is_number VALUE

is_boolean VALUE
```

Utilities should remain generic.

Project-specific logic belongs elsewhere.

---

# dependencies.sh

## Purpose

Validate required runtime dependencies.

## Planned Public API

```bash
check_dependencies

require_command COMMAND
```

### Planned Dependencies

* bash
* jq
* curl
* logger
* upsc
* systemctl

Additional dependencies may be added as the project evolves.

---

# nut.sh

## Purpose

Communicate with Network UPS Tools.

## Public API

```bash
nut_is_online

nut_is_on_battery

nut_is_charging

nut_get_charge

nut_get_runtime

nut_get_voltage

nut_get_load

nut_get_status
```

`nut_refresh_state` is deferred until `state.sh` exists (v0.5.0): there is
nothing to refresh into yet.

### Behaviour

Wraps `upsc` only (read-only). Never calls `upscmd`, `upsdrvctl` or any
command that could affect the UPS. Returns failure instead of guessing when
the UPS is unreachable.

### Notes

This module should never make shutdown decisions.

Its only responsibility is collecting UPS information.

---

# proxmox.sh

## Purpose

Communicate with the Proxmox API.

## Planned Public API

```bash
proxmox_login

proxmox_logout

proxmox_shutdown_vm VM_ID

proxmox_shutdown_container CT_ID

proxmox_shutdown_node

proxmox_get_status
```

Shutdown policy belongs to the Shutdown Engine.

---

# shutdown.sh

## Purpose

Coordinate shutdown of hosts that have no NUT client (Proxmox and NUT
secondaries already shut down natively via NUT; this is for everything
else, e.g. a managed switch or future non-NUT host).

## Public API

```bash
shutdown_start HOST

shutdown_cancel HOST

shutdown_status HOST

shutdown_execute HOST COMMAND [TIMEOUT_SECONDS]
```

### Responsibilities

* `shutdown_start`: idempotent — marks `HOST` `in_progress`; a second call
  while already `in_progress`/`completed` is a no-op.
* `shutdown_execute`: runs one stage/`COMMAND` (e.g. an `ssh` call) for
  `HOST` with a timeout (default 30s, no GNU `timeout` dependency). A host
  with several stages (a graceful attempt, then a harder one) is driven by
  calling this once per stage. Idempotent: a `completed` host is skipped;
  a `failed` one may be retried.
* `shutdown_cancel`: marks `HOST` `cancelled`; `shutdown_execute` then
  refuses to run. Can't undo a command that already ran.
* `shutdown_status`: reads the state recorded by the above (via `state.sh`
  — call `state_load` first). Empty string means never started.
* `SHUTDOWN_DRY_RUN` defaults to `true` (CLAUDE.md safety rule: never run a
  real shutdown command outside an explicit, deliberate opt-out). Set to
  `false` to actually run `shutdown_execute`'s command.
* Host lists and per-host commands/timeouts are not yet wired to config:
  there is no real non-NUT host in the current topology (Proxmox, RP-node1
  and the future NAS are all native NUT clients) — this is the generic
  engine, called directly with a host/command/timeout once a real
  consumer exists.

---

# notify.sh

## Purpose

Send notifications through supported providers.

## Public API

```bash
notify_info MESSAGE

notify_warning MESSAGE

notify_error MESSAGE

notify_success MESSAGE
```

### Behaviour

* Provider: `ntfy`, called directly over HTTP (no dependency on any alerting
  stack, since a power event must still notify if that stack is down).
* Configured via `NOTIFICATIONS_ENABLED` (energy.conf) and `NTFY_URL` /
  `NTFY_TOPIC` / `NTFY_TOKEN` (secrets, never in Git — see
  `config/secrets.env.example`).
* Fails safe: a notification error is logged via `log_warn` and never
  propagates, so it can never block or delay a shutdown.

---

# metrics.sh

## Purpose

Expose homelab-energy's own metrics (NUT/UPS metrics are already covered by
`nut_exporter`, a separate tool — see `templates/`) to Prometheus via
node_exporter's textfile collector.

## Public API

```bash
metrics_update NAME VALUE

metrics_increment NAME

metrics_collect

metrics_export
```

### Behaviour

* `metrics_update`/`metrics_increment`: record a value, backed by `state.sh`
  (call `state_load` first, `state_save` to persist) under a `metrics:`
  key prefix. `notify.sh` calls `metrics_increment` itself to track
  `notify_sent`/`notify_failed`; `bin/homelab-energy` records
  `last_event`/`last_event_at`.
* `metrics_collect`: prints the current values, plus every `shutdown.sh`
  host status, as Prometheus text exposition format (with `# HELP`/`# TYPE`).
  Never queries `upsc`/`curl`/`ssh` itself — only reports what the other
  modules already recorded.
* `metrics_export`: writes `metrics_collect`'s output to `METRICS_FILE`
  (default `/var/lib/node_exporter/textfile_collector/homelab_energy.prom`)
  atomically (tmp + `mv`, same pattern as `state_save`).

Initial target:

* Prometheus (via node_exporter's textfile collector)

Future targets:

* OpenTelemetry
* InfluxDB

---

# Public vs Private Functions

Public functions:

```bash
load_config

log_info

state_get

nut_get_status
```

Private functions:

```bash
_load_json

_write_console

_format_message

_parse_runtime
```

Private functions always begin with an underscore (`_`).

They must never be used outside their module.

---

# Compatibility Policy

Public APIs should remain stable whenever possible.

Implementation details may change without affecting other modules.

If a breaking change is required, all dependent modules should be updated in the same commit.

---

# Error Handling

Public functions should:

* Return meaningful exit codes.
* Log relevant failures.
* Never leave partial state.

Whenever possible, failures should be recoverable.

---

# Future Modules

Potential future APIs include:

```text
homeassistant.sh

mqtt.sh

history.sh

scheduler.sh

telegram.sh

dashboard.sh
```

New modules should follow the same design principles described in this document.
