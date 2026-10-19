# Project Roadmap

This document reflects the real, current plan for Homelab Energy. See `CLAUDE.md`
for the full architectural decision and topology behind it.

## Architecture decision (not negotiable without discussion)

NUT detects and decides; homelab-energy orchestrates, notifies and logs.

- Do not reimplement in Bash what NUT already does: ONBATT/ONLINE detection
  (`upsmon`), cancellable timers (`upssched`), low battery / FSD, final SAI cutoff.
- Entry point: `upssched` calls `bin/homelab-energy event <event>` as `CMDSCRIPT`.
- Proxmox shuts down as a NUT `secondary` client, not via SSH/API from this project.

## Current version

```text
0.7.0-dev
```

v0.8.0 is blocked (no real NAS to integrate yet) and v1.0.0 is partially
done (the runbook is written; the actual power-cut test is a manual,
physical step) — see both sections below. The version number stays at
the last fully-completed milestone.

## Milestones

| Version | Goal |
|---|---|
| v0.1.1 | ✅ Cleanup: fix the known bugs below, CI running `make check` in full |
| v0.2.0 | ✅ `bootstrap.sh` + `config.sh` (parser, layers, int/bool validation, clear errors) + configurable logger |
| v0.3.0 | ✅ `notify.sh` (one provider first; secrets out of Git) + `nut.sh` (`upsc` wrapper, read-only) |
| v0.4.0 | ✅ verified on RP-node2 with a real power cut (2026-10-19), notifying over Telegram — `bin/homelab-energy event` wired to `upssched` → **first production use: power loss/restore/low battery alerts** |
| v0.5.0 | ✅ `state.sh`: JSON via `jq`, atomic writes (tmp + `mv`), locking with `flock` |
| v0.6.0 | ✅ Shutdown engine for hosts without a NUT client (configurable stages, timeouts, idempotency, `--dry-run`) |
| v0.7.0 | ✅ fully deployed and verified live (2026-10-19) — Observability: `node_exporter`+textfile and `nut_exporter` on RP-node2, scraped by RP-node1's existing Prometheus, Grafana dashboards with real data |
| v0.8.0 | 🚫 blocked — NAS (TrueNAS as a native NUT secondary) and new nodes |
| v1.0.0 | ✅ runbook, ⏳ the real power-cut test itself is manual/physical |

## v0.1.1 bugs (fix first)

1. ~~`.github/workflows/quality.yml`: `make format-ckeck` typo and CI doesn't run tests.~~
2. ~~`make test` uses `find -exec` and never fails even if a test fails.~~
3. ~~`lib/test.sh`: `assert_false` was a copy of `assert_success`.~~
4. ~~`format` uses `shfmt -i 4` and `format-check` didn't: perpetual diffs.~~
5. ~~Libraries ran `set -Eeuo pipefail` on load.~~
6. ~~`lib/logger.sh`: `LOGGER_FILE_PATH` was relative; `LOG_LEVEL` name wasn't mapped to a numeric level.~~
7. ~~`lib/config.sh` sourced the `.conf` files and used `hosts.conf` instead of `hosts/<hostname>.conf`.~~
8. ~~`docs/roadmap.md` was stale; `docs/coding-standarts.md` → `coding-standards.md`.~~

## v0.2.0 delivered

* `lib/bootstrap.sh`: the only module allowed to `set -Eeuo pipefail` and source
  other libraries (`utils.sh`, `logger.sh`, `config.sh`). Exposes `bootstrap`.
* `lib/config.sh`: layered loading (`config/defaults.conf` required →
  `config/energy.conf` optional → `config/hosts/<hostname>.conf` optional),
  `config_get`/`config_exists`/`reload_config`, and int/bool validation with
  clear errors instead of silent `source`.
* `lib/logger.sh`: `logger_set_level` maps a config `LOG_LEVEL` name to the
  numeric level `bootstrap` wires in automatically.

## v0.3.0 delivered

* `lib/nut.sh`: read-only `upsc` wrapper (`nut_get_status`, `nut_get_charge`,
  `nut_get_runtime`, `nut_get_voltage`, `nut_get_load`,
  `nut_is_online`/`nut_is_on_battery`/`nut_is_charging`). Never calls
  `upscmd`/`upsdrvctl`; an unreachable UPS fails rather than guessing.
  `nut_refresh_state` (periodic poll into `state.sh`) still isn't built —
  see `docs/api.md`'s `nut.sh` section for why it's deferred indefinitely,
  not tied to a version: the event-driven design never needed a poll.
* `lib/notify.sh`: `notify_info`/`notify_success`/`notify_warning`/`notify_error`
  push directly over HTTP to an alerting channel — no Alertmanager hop, so a
  power event can still notify even if the rest of the monitoring stack is
  down. Fails safe: a `curl` error is logged and never propagates, so it
  can't block a shutdown. **Amendment (real RP-node2 deployment, see
  below)**: originally shipped against `ntfy`; swapped to the Telegram Bot
  API before going live, reusing the same bot/chat already used by Kuma/
  Alertmanager — same direct-HTTP, no-local-dependency design, just a
  different provider. See `docs/api.md`'s `notify.sh` section for the
  current (Telegram) behaviour.
* `lib/config.sh`: added an optional secrets layer (`.env` locally or
  `/etc/homelab-energy/secrets.env` in production) loaded after `hosts/`, with
  a hard refusal if the file is readable by group/others. Secrets never land
  in `defaults.conf`/`energy.conf` — see `config/secrets.env.example`.
* `lib/bootstrap.sh` now also sources `nut.sh` and `notify.sh`, matching the
  composition root in `docs/architecture.md`.

## v0.4.0 delivered

* `bin/homelab-energy event <NUT_EVENT_NAME>`: handles `ONBATT`/`ONLINE`/`LOWBATT`
  (log + notify); any other event is logged and ignored rather than failing
  the hook. Never makes a shutdown decision — NUT already decided.
* `bin/homelab-energy-cmdscript`: the actual `CMDSCRIPT` target. `upssched`
  calls a `CMDSCRIPT` with exactly one argument, so this shim adapts that
  into `homelab-energy event <name>`.
* `templates/upssched.conf.example`: the `upssched.conf` wiring (`CMDSCRIPT`
  + `AT ... EXECUTE` rules) for RP-node2.
* `make lint`/`format`/`format-check` now also cover `bin/*` (previously
  only matched `*.sh`, silently skipping the new extension-less entry points).

**Deployed for real on RP-node2 (2026-10-19)**, with findings that took more
than just "apply the template":

* `NOTIFYCMD upssched-cmd` (the documented norm) silently did nothing on
  this NUT 2.8.1 — no log, no error, no `CMDSCRIPT` call. `NOTIFYCMD
  /usr/sbin/upssched` directly works, since this config only needs
  immediate `EXECUTE` (no `START-TIMER`/`CANCEL-TIMER`), so `upssched-cmd`'s
  daemon/pipe layer buys nothing here anyway. See `CLAUDE.md`'s
  "Comportamiento de NUT ya medido" and the updated
  `templates/upssched.conf.example`.
* `upsmon` runs `NOTIFYCMD` as its own notify user (`nut` on this box, split
  from the root process that does the real shutdown), not the checkout's
  owner (`pi`). This needed: `chmod g+x` on `/home/pi` (a restrictive home
  directory blocks traversal even when every subdirectory below it is
  world-readable) with `nut` added to the `pi` group; `/etc/homelab-energy/
  secrets.env` owned by `nut` (not `pi` — `config.sh`'s permission check
  rejects a secrets file any other user can read, including the checkout's
  owner); and `bin/homelab-energy-cmdscript` now pins
  `STATE_DIR=/var/lib/homelab-energy` (`state.sh`'s repo-local default
  isn't writable by `nut`).
* Verified with a real ~30s power cut: `ONBATT` and `ONLINE` both fired,
  both notified over Telegram, `state.json` updated correctly. The one
  failure was metrics export (`/var/lib/node_exporter` doesn't exist
  yet, that's v0.7.0's remaining deployment step below) — handled exactly
  as designed: logged, didn't block anything else.

## v0.5.0 delivered

* `lib/state.sh`: `state_load`/`state_save`/`state_get`/`state_set`/`state_delete`/
  `state_exists`, backed by a single `state/state.json`. `state_load` reads
  the file into the in-memory `STATE_JSON` string; `state_get`/`set`/`delete`/
  `exists` only touch that string via `jq`; `state_save` writes a temp file
  and `mv`s it into place.
* Both `state_load` and `state_save` hold an exclusive `flock` on
  `state/state.lock` (fixed fd 200, not bash 4's `{fd}` auto-allocation, to
  stay compatible with macOS's bash 3.2) — last-writer-wins, no merge logic.
* `flock` doesn't ship with macOS; `brew install flock` (discoteq/flock) is
  close enough to the util-linux one on the Pi for this usage, except `-w 0`
  means something different between them, so it's avoided. See
  `docs/architecture.md`'s "Platform Compatibility" section for this and
  the other macOS/Raspberry Pi differences baked into the codebase.
* `lib/bootstrap.sh` now also sources `state.sh`. At this point nothing
  wired it into `bin/homelab-energy` yet — the first real consumer ended
  up being `metrics.sh` (v0.7.0: `last_event`/counters) rather than the
  shutdown engine this note originally expected; `shutdown.sh` (v0.6.0)
  uses `state.sh` directly for its own `shutdown:<host>` keys.

## v0.6.0 delivered

* `lib/shutdown.sh`: `shutdown_start HOST` (idempotent), `shutdown_execute
  HOST COMMAND [TIMEOUT_SECONDS]` (one stage, portable timeout — no GNU
  `timeout` dependency), `shutdown_cancel HOST`, `shutdown_status HOST`.
  Backed by `state.sh` (call `state_load` first). "Stages" = calling
  `shutdown_execute` once per stage (a graceful attempt, then a harder one),
  not a baked-in multi-stage DSL.
* `SHUTDOWN_DRY_RUN` defaults to `true` (CLAUDE.md safety rule): a real
  command only runs with an explicit `SHUTDOWN_DRY_RUN=false`.
* No real host needs this yet — Proxmox, RP-node1 and the future NAS are
  all native NUT clients (see topology in `CLAUDE.md`); this is the generic
  engine, called directly with host/command/timeout rather than wired to a
  config-driven host list, until a real non-NUT host exists to wire it to.
* `lib/bootstrap.sh` now also sources `shutdown.sh`.

## v0.7.0 delivered

* `lib/metrics.sh`: `metrics_update NAME VALUE`/`metrics_increment NAME`
  (backed by `state.sh`, a `metrics:` key prefix), `metrics_collect`
  (Prometheus text format, with `# HELP`/`# TYPE`), `metrics_export`
  (atomic tmp+`mv` write to `METRICS_FILE`, default
  `/var/lib/node_exporter/textfile_collector/homelab_energy.prom`).
* Exposes: last NUT event handled + its timestamp, notifications
  sent/failed (via `notify.sh` calling `metrics_increment` itself, the only
  place that actually sees whether `curl` succeeded), and every
  `shutdown.sh` host's status (scanned from state, no separate host
  registry needed).
* `bin/homelab-energy` now calls `state_load`/`state_save` and
  `metrics_update` around `_handle_event`, and `metrics_export` after —
  guarded with `log_warn` on failure so a bad/missing textfile-collector
  path never fails the hook.
* `lib/bootstrap.sh` now also sources `metrics.sh`.
* `templates/nut_exporter.service.example` (systemd unit for RP-node2),
  `templates/prometheus.yml.example` and
  `templates/docker-compose.observability.yml.example` (Prometheus+Grafana
  for RP-node1), `templates/node_exporter_textfile.example` (wiring
  `METRICS_FILE` to node_exporter's textfile collector directory).

**Deployed for real (2026-10-19)**, with findings not fixable from this
repo alone:

* `node_exporter` and `nut_exporter` installed fresh on RP-node2 as
  systemd services (own system users, not reusing `nut`). The textfile
  collector directory is owned by `nut` (the writer) and world-readable
  (`755`) rather than shared-group, because `metrics_export` now
  `chmod 644`s its output — `mktemp`'s default `600` would otherwise be
  unreadable by `node_exporter`'s own, unrelated service user (fixed in
  `lib/metrics.sh`, see the commit history).
* RP-node1 already ran Prometheus/Grafana/Alertmanager/Uptime Kuma in
  Docker (managed via Arcane) — `templates/docker-compose.observability.yml.example`
  was never applied; `templates/prometheus.yml.example`'s two new jobs
  (`rp_node2`, `nut`) were added to the real, existing
  `/home/pi/monitoring-stack/prometheus/prometheus.yml` instead, matching
  its own job-naming convention. See `CLAUDE.md`'s topology section for
  the full real config location and the `docker restart prometheus`
  reload gotcha (no lifecycle API).
* `nut_exporter`'s `--nut.vars_enable` **replaces**, not appends to, the
  built-in default — had to list it in full to add `battery.runtime` for
  Grafana's Runtime panel. `ups.realpower` was deliberately left out:
  this UPS only reports `ups.realpower.nominal` (a fixed rated value),
  never a live reading, so a Power panel stays empty regardless.
* Grafana dashboard: `19308` ("Prometheus NUT Exporter for DRuggeri"),
  imported as-is.

## v0.8.0: blocked

No NAS exists in the current topology (`CLAUDE.md`'s topology table has
Proxmox, RP-node1 and the SAI only). TrueNAS's NUT client is configured on
the NAS itself via its own UI, not in this repo — there is nothing for
homelab-energy to build until a real NAS is added. Revisit when one is.

## v1.0.0: runbook delivered, real test still manual

* `docs/runbook.md`: the real power-cut test procedure, grounded in the
  measured NUT behaviour from `CLAUDE.md` (the primary's ~60s secondary
  wait regardless of `HOSTSYNC`, the real `ups.delay.shutdown=180` margin,
  the FSD cleanup order that bit a previous test). Covers pre-test
  checks, expected event sequence, cleanup order, and what to check if
  something goes wrong.
* The test itself — physically cutting utility power and watching the
  whole chain react — is Joel's manual, physical action. Nothing in this
  repo can run it.

## Definition of done

A task is complete when:

* The implementation is finished.
* Tests have been added.
* Documentation reflects the code, not a plan.
* `make check` passes (format, lint, tests).
* GitHub Actions pass.
* The project remains deployable.

Main should always be deployable. Broken code should never be committed.
