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
0.1.1-dev
```

## Milestones

| Version | Goal |
|---|---|
| v0.1.1 | Cleanup: fix the known bugs below, CI running `make check` in full |
| v0.2.0 | `bootstrap.sh` + `config.sh` (parser, layers, int/bool validation, clear errors) + configurable logger |
| v0.3.0 | `notify.sh` (one provider first; secrets out of Git) + `nut.sh` (`upsc` wrapper, read-only) |
| v0.4.0 | `bin/homelab-energy event` wired to `upssched` → **first production use: power loss/restore/low battery alerts** |
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

## Definition of done

A task is complete when:

* The implementation is finished.
* Tests have been added.
* Documentation reflects the code, not a plan.
* `make check` passes (format, lint, tests).
* GitHub Actions pass.
* The project remains deployable.

Main should always be deployable. Broken code should never be committed.
