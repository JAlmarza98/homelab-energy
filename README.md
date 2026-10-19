# Homelab Energy

A lightweight, modular and extensible Bash framework for monitoring UPS devices and orchestrating energy-aware actions across a homelab.

The project is designed around simplicity, reliability and maintainability, with a strong focus on modular architecture and automated testing.

---

# Features

Current implementation:

* Bootstrap framework
* Layered configuration (`defaults.conf` → `energy.conf` → `hosts/<hostname>.conf` → secrets)
* UPS monitoring (Network UPS Tools, read-only)
* Alerting and notifications (Telegram)
* `bin/homelab-energy event` wired to `upssched` (power loss/restore/low battery)
* Persistent state (`state.sh`, JSON + atomic writes + `flock`)
* Shutdown engine for hosts without a NUT client (`shutdown.sh`, `--dry-run` by default)
* Custom metrics for Prometheus via node_exporter's textfile collector (`metrics.sh`)
* Modular logging framework
* Lightweight testing framework
* Development tooling (ShellCheck, shfmt, Make)
* Modular project architecture
* Documentation and coding standards

Planned features:

* Proxmox integration
* Grafana integration
* Scheduled tasks
* Multi-host support

---

# Project Structure

```text
.
├── bin/            entry points (homelab-energy, homelab-energy-cmdscript)
├── config/         defaults.conf, energy.conf, hosts/, secrets.env.example
├── docs/
├── lib/            modules sourced via bootstrap.sh
├── logs/           created on demand by logger.sh (LOGGER_HANDLER_FILE); gitignored
├── services/       reserved for real systemd units, once something installs them;
│                   deployment *examples* live in templates/ instead, for now
├── state/          created on demand by state.sh (state.json, state.lock); gitignored
├── templates/      deployment examples (upssched.conf, nut_exporter, Prometheus/Grafana) — never applied automatically
└── tests/
```

---

# Development

## Format

```bash
make format
```

Verify formatting:

```bash
make format-check
```

Run ShellCheck:

```bash
make lint
```

Run all tests:

```bash
make test
```

Run all quality checks:

```bash
make check
```

---

# Usage

```bash
# Called by upssched as CMDSCRIPT (see templates/upssched.conf.example) —
# not normally run by hand, but safe to:
bin/homelab-energy event ONBATT    # power lost: logs + notifies
bin/homelab-energy event ONLINE    # power restored
bin/homelab-energy event LOWBATT   # battery critically low
```

Every call logs, notifies via Telegram (if `NOTIFICATIONS_ENABLED=true` and
a real `TELEGRAM_BOT_TOKEN`/`TELEGRAM_CHAT_ID` are configured), records the
event in `state/state.json`, and exports metrics to `METRICS_FILE` for
Prometheus. See `docs/api.md` for the full `bin/homelab-energy` contract
and every module's public API.

---

# Documentation

Additional documentation can be found in the `docs/` directory.

Current documents:

* [`docs/architecture.md`](docs/architecture.md) — design principles, module
  layout, platform compatibility (macOS vs. Raspberry Pi)
* [`docs/api.md`](docs/api.md) — every module's public functions, config
  keys, and env-var overrides
* [`docs/coding-standards.md`](docs/coding-standards.md) — naming, file
  structure, error handling conventions
* [`docs/testing.md`](docs/testing.md) — test strategy, isolation patterns,
  per-module test breakdown
* [`docs/roadmap.md`](docs/roadmap.md) — milestone-by-milestone status,
  what shipped and why
* [`docs/runbook.md`](docs/runbook.md) — the real power-cut test procedure

---

# Development Principles

The project follows a few core principles.

* One responsibility per module.
* Public APIs separated from internal helpers.
* Explicit behaviour over implicit behaviour.
* Readability over cleverness.
* Small and reusable components.
* Incremental evolution.
* Test-first mindset whenever practical.

---

# Roadmap

The next milestones are:

* Proxmox automation
* NAS integration (native NUT secondary) — blocked until a real NAS exists

---

# Requirements

Development tools:

* Bash
* Make
* ShellCheck
* shfmt

Runtime dependencies:

* `jq` and `flock` (`state.sh`)
* `curl` (`notify.sh`)
* `upsc` (`nut.sh`)

Kept to the minimum needed by the modules that actually use them.

---

# Current Status

The core framework (bootstrap, layered config, logging, NUT reads,
notifications, persistent state, a generic shutdown engine, and
Prometheus metrics) is implemented and tested, but **not yet installed
on real hardware** — see `docs/roadmap.md` for the exact milestone
breakdown of what's done in the repo versus what's still a manual
deployment step on RP-node1/RP-node2.

NAS integration is blocked until a real NAS exists in the topology, and
the real power-cut test (`docs/runbook.md`) is a physical action that
hasn't been run yet.

---

# License

This project is currently intended for personal and educational use.

A license will be added before the first public release.
