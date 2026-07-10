# Project Roadmap

This document defines the planned evolution of the Homelab Energy project.

The roadmap is divided into milestones.

Each milestone should result in a stable and usable version.

---

# Vision

Homelab Energy aims to become the central energy management platform for the entire homelab.

The final system should be capable of:

* Monitoring one or more UPS devices
* Detecting power events
* Coordinating graceful shutdown procedures
* Publishing metrics
* Sending notifications
* Providing a modular architecture for future integrations

The project prioritizes reliability over feature count.

---

# Current Version

```text
0.1.0-dev
```

Status:

🚧 Under active development

---

# Milestone 0.1.0 — Project Foundation

## Goal

Create a solid architecture before implementing business logic.

### Deliverables

* Repository structure
* Documentation
* Bootstrap module
* Logger module
* Configuration manager
* State manager
* Utility library
* Dependency validation
* Makefile
* GitHub Actions
* ShellCheck
* shfmt

### Exit Criteria

* Project builds successfully
* Documentation completed
* All quality checks pass
* First stable commit

---

# Milestone 0.2.0 — NUT Integration

## Goal

Integrate Network UPS Tools.

### Deliverables

* NUT module
* UPS status wrapper
* Battery monitoring
* Runtime monitoring
* Event detection
* Automatic state synchronization

### Exit Criteria

* UPS detected correctly
* Runtime state updated automatically
* Monitoring survives UPS reconnects

---

# Milestone 0.3.0 — Power Event Engine

## Goal

Detect and classify power events.

### Deliverables

* Online detection
* Battery detection
* Low battery detection
* Critical battery detection
* Recovery detection

### Exit Criteria

* Events generated correctly
* Duplicate events avoided
* Event transitions validated

---

# Milestone 0.4.0 — Shutdown Engine

## Goal

Provide a deterministic shutdown workflow.

### Deliverables

* Shutdown policies
* Configurable delays
* Grace periods
* Ordered execution
* Cancellation support

### Exit Criteria

* Full shutdown sequence tested
* Recovery scenarios validated

---

# Milestone 0.5.0 — Proxmox Integration

## Goal

Control Proxmox using its API.

### Deliverables

* Authentication
* VM shutdown
* LXC shutdown
* Node shutdown
* Status checks

### Exit Criteria

* Controlled shutdown of production environment
* Retry logic implemented

---

# Milestone 0.6.0 — NAS Integration

## Goal

Support NAS shutdown procedures.

### Planned Targets

* Custom NAS
* Synology (future)
* Generic SSH shutdown

### Exit Criteria

* NAS powered down safely
* Configurable shutdown order

---

# Milestone 0.7.0 — Monitoring

## Goal

Expose metrics for observability.

### Deliverables

* Prometheus exporter
* Grafana dashboard
* Runtime statistics
* Battery history

### Exit Criteria

* Dashboard available
* Metrics updated automatically

---

# Milestone 0.8.0 — Notifications

## Goal

Notify administrators about relevant events.

### Planned Providers

* Telegram
* Discord
* Email

### Events

* Power failure
* Battery threshold reached
* Shutdown started
* Shutdown completed
* Utility restored

### Exit Criteria

* Notification providers configurable
* Retry policy implemented

---

# Milestone 0.9.0 — Automation

## Goal

Reduce manual administration.

### Deliverables

* Scheduled health checks
* Self-tests
* Automatic UPS tests
* Periodic reports

---

# Milestone 1.0.0 — Stable Release

## Goal

First production-ready release.

### Requirements

* Complete documentation
* Comprehensive test suite
* Stable APIs
* Configuration templates
* Installation guide
* Upgrade guide

### Quality Requirements

* ShellCheck clean
* shfmt clean
* GitHub Actions passing
* Manual validation completed

---

# Future Ideas

The following features are outside the current roadmap but remain possible future extensions.

## Infrastructure

* Multiple UPS devices
* High Availability
* Cluster awareness

---

## Integrations

* Home Assistant
* MQTT
* Slack
* Microsoft Teams
* ntfy
* Pushover

---

## Monitoring

* Battery degradation history
* Runtime prediction
* Power consumption estimation

---

## Dashboard

* Web UI
* Historical charts
* Event timeline
* System overview

---

# Development Workflow

Every feature should follow the same lifecycle.

```text
Idea
    │
Design
    │
Implementation
    │
Testing
    │
Refactoring
    │
Documentation
    │
Quality Checks
    │
Commit
```

No feature should be considered complete until every step has been completed.

---

# Definition of Done

A task is considered complete when:

* The implementation is finished
* Tests have been added
* Documentation has been updated
* ShellCheck passes
* shfmt passes
* GitHub Actions pass
* The project remains deployable

---

# Release Philosophy

Small, incremental releases are preferred over large feature drops.

Every milestone should leave the project in a usable and stable state.

Main should always be deployable.

Broken code should never be committed.
