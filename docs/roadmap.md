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
0.4.0-dev
```

## Milestones

| Version | Goal |
|---|---|
| v0.1.1 | ✅ Cleanup: fix the known bugs below, CI running `make check` in full |
| v0.2.0 | ✅ `bootstrap.sh` + `config.sh` (parser, layers, int/bool validation, clear errors) + configurable logger |
| v0.3.0 | ✅ `notify.sh` (one provider first; secrets out of Git) + `nut.sh` (`upsc` wrapper, read-only) |
| v0.4.0 | ✅ in repo, ⏳ not yet installed on RP-node2 — `bin/homelab-energy event` wired to `upssched` → **first production use: power loss/restore/low battery alerts** |
| v0.5.0 | `state.sh`: JSON via `jq`, atomic writes (tmp + `mv`), locking with `flock` |
| v0.6.0 | Shutdown engine for hosts without a NUT client (configurable stages, timeouts, idempotency, `--dry-run`) |
| v0.7.0 | Observability: `nut_exporter` on RP-node2, custom metrics via node_exporter textfile, Prometheus/Grafana on RP-node1 |
| v0.8.0 | NAS (TrueNAS as a native NUT secondary) and new nodes |
| v1.0.0 | Real power-cut test, documented runbook |

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
  `nut_refresh_state` deferred to v0.5.0 (needs `state.sh`).
* `lib/notify.sh`: `notify_info`/`notify_success`/`notify_warning`/`notify_error`
  push to `ntfy` directly over HTTP — no Alertmanager hop, so a power event can
  still notify even if the rest of the monitoring stack is down. Fails safe: a
  `curl` error is logged and never propagates, so it can't block a shutdown.
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

**Remaining for real production use**: install `templates/upssched.conf.example`
as `/etc/nut/upssched.conf` on RP-node2 (adjusting the `CMDSCRIPT` path),
confirm `upsmon.conf` has `NOTIFYCMD upssched-cmd` and `NOTIFYFLAG` set for
`ONBATT`/`ONLINE`/`LOWBATT`, set real `NTFY_TOPIC`/`NTFY_URL` in
`/etc/homelab-energy/secrets.env` (chmod 600), and set `NOTIFICATIONS_ENABLED=true`
in `energy.conf`. This is a manual deployment step on the Pi, not something
done from this repo.

## Definition of done

A task is complete when:

* The implementation is finished.
* Tests have been added.
* Documentation reflects the code, not a plan.
* `make check` passes (format, lint, tests).
* GitHub Actions pass.
* The project remains deployable.

Main should always be deployable. Broken code should never be committed.
