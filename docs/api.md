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

## Planned Public API

```bash
nut_is_online

nut_is_on_battery

nut_is_charging

nut_get_charge

nut_get_runtime

nut_get_voltage

nut_get_load

nut_get_status

nut_refresh_state
```

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

Coordinate infrastructure shutdown.

## Planned Public API

```bash
shutdown_start

shutdown_cancel

shutdown_status

shutdown_execute
```

### Responsibilities

* Execute shutdown policies.
* Respect configured delays.
* Execute ordered shutdown steps.
* Track execution progress.

---

# notify.sh

## Purpose

Send notifications through supported providers.

## Planned Public API

```bash
notify_info MESSAGE

notify_warning MESSAGE

notify_error MESSAGE

notify_success MESSAGE
```

Supported providers will be configurable.

---

# metrics.sh

## Purpose

Expose metrics for monitoring systems.

## Planned Public API

```bash
metrics_export

metrics_update

metrics_collect
```

Initial target:

* Prometheus

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
