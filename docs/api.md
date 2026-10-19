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

logger_set_level NAME
```

### Behaviour

* Adds timestamp.
* Adds log level.
* Writes to configured outputs.
* Honors configured log level.
* `logger_set_level NAME` maps a level name (`DEBUG`/`INFO`/`SUCCESS`/`WARN`/
  `ERROR`) to `LOGGER_LEVEL`'s numeric value; returns 1 and logs nothing on
  an unknown name. `bootstrap()` calls this with `config_get LOG_LEVEL`, so
  `LOG_LEVEL` in `energy.conf` drives it end to end.

### Levels

| Name | Numeric value |
|---|---|
| `DEBUG` | 10 |
| `INFO` | 20 |
| `SUCCESS` | 25 |
| `WARN` | 30 |
| `ERROR` | 40 |

A record is emitted only when its level is `>= LOGGER_LEVEL`.

### Handlers

Three handler toggles, each a plain `true`/`false` variable (not yet wired
to `config/*.conf` — set directly before calling a `log_*` function, or add
the wiring when a real need for file/journald logging shows up):

| Variable | Default | Effect |
|---|---|---|
| `LOGGER_HANDLER_CONSOLE` | `true` | Colored output to stdout. |
| `LOGGER_HANDLER_FILE` | `false` | Plain (no ANSI) append to `LOGGER_FILE_PATH`. |
| `LOGGER_HANDLER_JOURNALD` | `false` | Not implemented yet (`_logger_journald` is a stub); reserved for `systemd-cat`. |

`LOGGER_FILE_PATH` defaults to `${PROJECT_ROOT}/logs/energy.log`.

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

* Files are **parsed** (`CLAVE=valor`, comments and blank lines skipped,
  key validated against `^[A-Za-z_][A-Za-z0-9_]*$`), never `source`d — a
  config file cannot execute arbitrary shell code.
* `config_get`/`config_exists` use bash's indirect expansion (`${!key}`)
  against whatever `load_config` last assigned as plain global variables —
  there is no separate associative array (keeps `printf -v` dynamic
  assignment, which works on bash 3.2 too; `declare -A` would not).
* `reload_config` is just `load_config` again: layers are re-parsed and
  later ones overwrite earlier ones, so a key removed from a later layer
  keeps whatever an earlier layer set (there is no "unset" between reloads).

### Layers (in order, later overrides earlier)

| # | File | Required? | Purpose |
|---|---|---|---|
| 1 | `config/defaults.conf` | **Yes** — `load_config` exits 1 if missing | Safe baseline for every deployment. |
| 2 | `config/energy.conf` | No | This site's real values. |
| 3 | `config/hosts/$(hostname).conf` | No | Per-host overrides (IPs, NUT server). `hostname` must match exactly — RP-node2's file is `config/hosts/RP-node2.conf` (capitalised, per `CLAUDE.md`'s topology). |
| 4 | `${PROJECT_ROOT}/.env` (local) | No | Dev-only secrets, gitignored. |
| 5 | `/etc/homelab-energy/secrets.env` (production) | No | Real secrets. Both this and layer 4, if present, must be `chmod 600` (group/world-unreadable) or `load_config` refuses to load them and exits 1. |

After all layers, `_config_validate` enforces `SHUTDOWN_DELAY` is an
integer and `PROXMOX_ENABLED`/`NAS_ENABLED`/`NOTIFICATIONS_ENABLED`/
`PROMETHEUS_ENABLED` are each exactly `true` or `false` — `load_config`
exits 1 with a clear message otherwise.

`CONFIG_DIR`, `SECRETS_CONFIG_LOCAL` and `SECRETS_CONFIG_SYSTEM` are
themselves overridable via environment variable (set before sourcing
`config.sh`) — this is how tests point `load_config` at a throwaway
directory instead of the real `config/`.

### Config keys reference

Keys actually read from `config/*.conf` / secrets files:

| Key | First set in | Type | Default | Consumed by | Status |
|---|---|---|---|---|---|
| `PROJECT_NAME` | `defaults.conf` | string | `homelab-energy` | `notify.sh` (message prefix) | active |
| `UPS_NAME` | `defaults.conf` | string | `ups` | `nut.sh` (`upsc` target) | active |
| `SHUTDOWN_DELAY` | `defaults.conf` | int | `60` | — | reserved — `shutdown.sh`'s `shutdown_execute` takes its timeout as a function argument instead; nothing reads this yet |
| `LOG_LEVEL` | `defaults.conf` | `DEBUG`\|`INFO`\|`SUCCESS`\|`WARN`\|`ERROR` | `WARN` | `bootstrap()` → `logger_set_level` | active |
| `PROXMOX_ENABLED` | `defaults.conf` | bool | `false` | — | reserved for future Proxmox integration |
| `NAS_ENABLED` | `defaults.conf` | bool | `false` | — | reserved; blocked until a real NAS exists (v0.8.0) |
| `NOTIFICATIONS_ENABLED` | `defaults.conf` | bool | `false` | `notify.sh` | active |
| `PROMETHEUS_ENABLED` | `defaults.conf` | bool | `false` | — | reserved — `metrics.sh` currently always exports regardless of this flag |
| `PROXMOX_IP` | `hosts/<hostname>.conf` | string | (unset) | — | reserved for future Proxmox integration |
| `NAS_IP` | `hosts/<hostname>.conf` | string | (unset) | — | reserved; blocked (v0.8.0) |
| `NUT_SERVER` | `hosts/<hostname>.conf` | string | `localhost` (fallback inside `nut.sh`, not a config default) | `nut.sh` (`upsc` target) | active |
| `TELEGRAM_BOT_TOKEN` | secrets | string | (unset — notifications silently skip without it) | `notify.sh` (Bot API URL) | active, secret |
| `TELEGRAM_CHAT_ID` | secrets | string | (unset — notifications silently skip without it) | `notify.sh` | active, secret |

Environment-only overrides (never read from a `.conf` file — set as an
actual environment variable, mainly for tests or an unusual deployment):
`CONFIG_DIR`, `SECRETS_CONFIG_LOCAL`, `SECRETS_CONFIG_SYSTEM` (`config.sh`),
`STATE_DIR`, `STATE_LOCK_WAIT` (`state.sh`), `METRICS_FILE` (`metrics.sh`),
`SHUTDOWN_DRY_RUN` (`shutdown.sh`), `LOGGER_HANDLER_CONSOLE`/`_FILE`/
`_JOURNALD`, `LOGGER_FILE_PATH` (`logger.sh`, see above).

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
* The lock uses a **fixed** file descriptor (`STATE_LOCK_FD=200`, via
  `eval "exec 200>…"`), not bash 4's `exec {fd}>…` auto-allocation —
  macOS's default `/bin/bash` is 3.2, which doesn't have it.
* `STATE_DIR` (default `${PROJECT_ROOT}/state`) and `STATE_LOCK_WAIT`
  (default `5` seconds) are overridable environment variables, mainly for
  test isolation.

---

# utils.sh

## Purpose

Provide reusable, generic helper functions with no project-specific logic.

## Public API

```bash
command_exists COMMAND

require_command COMMAND...

file_exists FILE

directory_exists DIRECTORY

ensure_directory DIRECTORY

timestamp_now

timestamp_iso8601

timestamp_epoch
```

### Behaviour

* `command_exists`: `command -v` check, boolean return.
* `require_command`: true only if every argument passed is a known
  command (`bootstrap()` uses this: `require_command bash date mkdir
  hostname`).
* `file_exists`/`directory_exists`: thin `[[ -f/-d ]]` wrappers.
* `ensure_directory`: `mkdir -p`.
* `timestamp_now`: `date '+%Y-%m-%d %H:%M:%S'` (same format `logger.sh`
  uses).
* `timestamp_iso8601`: `date '+%Y-%m-%dT%H:%M:%S%z'` — deliberately **not**
  GNU's `date --iso-8601=seconds`, which doesn't exist on macOS's BSD
  `date` (this was v0.1.1 bug territory: `make test` silently never
  reaching this assertion is what hid it).
* `timestamp_epoch`: `date +%s`; used by `bin/homelab-energy` for
  `metrics:last_event_at`.

Utilities should remain generic. Project-specific logic (NUT, Proxmox,
notifications, …) belongs in its own module, never here.

---

# dependencies.sh — superseded

Originally planned as a single module validating `bash`/`jq`/`curl`/
`upsc`/`systemctl` up front. What actually shipped instead is per-module,
on-demand checks, closer to "fail at the point of use with a clear
message" than "fail at startup for things that might not even be needed
by this run":

* `bootstrap()` (`bootstrap.sh`) checks `bash date mkdir hostname` — the
  commands every run needs regardless of which subcommand runs.
* `state.sh`'s `_state_require_jq` checks `jq` only when a `state_*`
  function is actually called.
* `notify.sh`'s `_notify_send` checks `curl` only when a notification is
  actually about to be sent (and `NOTIFICATIONS_ENABLED` is checked first,
  so a disabled install never needs `curl` at all).
* `nut.sh` has no explicit check: `upsc` not existing surfaces as a
  command-not-found failure from `_nut_query`, which every `nut_get_*`
  caller already treats as "unreachable" (see `nut.sh` below).

No `lib/dependencies.sh` file exists, and none is currently planned —
revisit only if the per-module checks stop being clear enough in
practice.

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

`nut_refresh_state` (periodically polling `upsc` and writing the readings
into `state.sh`) still isn't implemented: `state.sh` exists since v0.5.0,
but nothing in the current event-driven design (`upssched` → `bin/
homelab-energy event`) needs a periodic poll — every call already has a
fresh NUT-decided event to react to. Add it if a future consumer (e.g. a
Prometheus scrape target wanting live `upsc` values rather than
`nut_exporter`'s) actually needs cached/polled readings.

### Behaviour

Wraps `upsc` only (read-only). Never calls `upscmd`, `upsdrvctl` or any
command that could affect the UPS. Returns failure instead of guessing when
the UPS is unreachable.

* Target is `${UPS_NAME:-ups}@${NUT_SERVER:-localhost}` — both fall back
  silently if unset, rather than failing, so this module stays usable
  standalone (e.g. in tests) without a full `config.sh` load. In the real
  deployment both come from config (`UPS_NAME` from `energy.conf`,
  `NUT_SERVER` from `hosts/RP-node2.conf`) — see the config keys table
  under `config.sh`.
* No explicit dependency check on `upsc`: if it's missing, `_nut_query`
  fails the same way an unreachable UPS would, and every `nut_get_*`/
  `nut_is_*` caller already has to handle that.

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

* Provider: Telegram Bot API (`https://api.telegram.org/bot<TOKEN>/sendMessage`),
  called directly over HTTP — no dependency on any alerting stack (e.g.
  Alertmanager), since a power event must still notify even if that stack
  is down. Reuses an existing bot/chat (e.g. one already used by other
  local monitoring) rather than requiring a dedicated one.
* Each severity prepends an emoji to the message (`notify_info` ℹ️,
  `notify_success` ✅, `notify_warning` ⚠️, `notify_error` 🚨) — Telegram
  has no equivalent of ntfy's `Priority`/`Tags` headers.
* Configured via `NOTIFICATIONS_ENABLED` (energy.conf) and
  `TELEGRAM_BOT_TOKEN` / `TELEGRAM_CHAT_ID` (secrets, never in Git — see
  `config/secrets.env.example`). Missing either one skips the send
  (logged via `log_warn`), it doesn't error.
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
