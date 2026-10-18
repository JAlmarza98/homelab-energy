# Homelab Energy

A lightweight, modular and extensible Bash framework for monitoring UPS devices and orchestrating energy-aware actions across a homelab.

The project is designed around simplicity, reliability and maintainability, with a strong focus on modular architecture and automated testing.

---

# Features

Current implementation:

* Bootstrap framework
* Layered configuration (`defaults.conf` → `energy.conf` → `hosts/<hostname>.conf` → secrets)
* UPS monitoring (Network UPS Tools, read-only)
* Alerting and notifications (ntfy)
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
├── bin/
├── config/
├── docs/
├── lib/
├── logs/
├── services/
├── state/
├── templates/
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

# Documentation

Additional documentation can be found in the `docs/` directory.

Current documents include:

* `ARCHITECTURE.md`
* `TESTING.md`
* `ROADMAP.md`
* `RUNBOOK.md` — the real power-cut test procedure

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

The project is under active development.

The current focus is building a robust and reusable framework that will support the monitoring and automation features planned for future releases.

---

# License

This project is currently intended for personal and educational use.

A license will be added before the first public release.
