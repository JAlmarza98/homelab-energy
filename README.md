# Homelab Energy

A lightweight, modular and extensible Bash framework for monitoring UPS devices and orchestrating energy-aware actions across a homelab.

The project is designed around simplicity, reliability and maintainability, with a strong focus on modular architecture and automated testing.

---

# Features

Current implementation:

* Bootstrap framework
* Layered configuration (`defaults.conf` → `energy.conf` → `hosts/<hostname>.conf`)
* Modular logging framework
* Lightweight testing framework
* Development tooling (ShellCheck, shfmt, Make)
* Modular project architecture
* Documentation and coding standards

Planned features:

* UPS monitoring (Network UPS Tools)
* Persistent state management
* Proxmox integration
* Grafana integration
* Alerting and notifications
* Scheduled tasks
* Multi-host support

---

# Project Structure

```text
.
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

* State management
* NUT integration
* Energy monitoring service
* Grafana dashboards
* Proxmox automation
* Notification system

---

# Requirements

Development tools:

* Bash
* Make
* ShellCheck
* shfmt

Runtime dependencies will be kept to the minimum possible.

---

# Current Status

The project is under active development.

The current focus is building a robust and reusable framework that will support the monitoring and automation features planned for future releases.

---

# License

This project is currently intended for personal and educational use.

A license will be added before the first public release.
