# Power-Cut Test Runbook

A real utility power outage, from the SAI switching to battery through
FSD and recovery. Based on the measured NUT behaviour in `CLAUDE.md` —
read that first if anything here seems to contradict NUT's defaults, since
defaults are not what this topology actually does.

This is a destructive-adjacent test on real infrastructure (Proxmox will
receive a real shutdown order if the test runs long enough). Run it only
when you can be physically present for the whole thing.

---

## Before the test

* `upsc apc@localhost ups.status` on RP-node2 is `OL` (online, not already
  on battery).
* No stale `/etc/killpower` on RP-node2 (leftover from a previous test
  would make `nut-driver@apc` refuse to start cleanly).
* `systemctl status nut-server nut-monitor nut-driver@apc` clean on
  RP-node2; `systemctl status nut-monitor` clean on Proxmox and RP-node1.
* `NOTIFICATIONS_ENABLED=true` and a real `NTFY_TOPIC` are set, and a test
  notification (`bin/homelab-energy event ONBATT` run manually, then
  `ONLINE` to clear it) actually arrives.
* Battery is healthy enough for the test to reach LOWBATT without the
  SAI's own internal low-voltage cutoff kicking in first (battery is from
  2020-03 per `CLAUDE.md` — if `upsc apc@localhost battery.charge` is
  already low, don't run this today).

## Running the test

1. Cut utility power to the SAI (unplug it from the wall, or kill the
   circuit — not `upsmon -c fsd`, not any simulated event: a real cut).
2. Expect, in order:
   * NUT's `upsmon` detects `ONBATT` within its poll interval.
   * `upssched` fires `bin/homelab-energy-cmdscript ONBATT` →
     `notify_warning` arrives, `metrics.sh`'s `last_event` becomes `ONBATT`.
   * If the outage is sustained past `battery.runtime.low=1200`s /
     `battery.charge.low=30`%: `LOWBATT` fires the same way
     (`notify_error`).
   * If the outage continues, `upsmon` issues FSD. **The primary
     (RP-node2) only waits ~60s for secondaries after FSD, even though
     `HOSTSYNC=300`** — Proxmox's and RP-node1's real margin is the SAI's
     own `ups.delay.shutdown=180`s, not `HOSTSYNC`.
   * Proxmox shuts down as a NUT secondary (not via SSH/API from this
     project) within that ~180s window.
   * The SAI cuts its output `ups.delay.shutdown` (180s) after the final
     shutdown order.
3. Restore utility power before, at, or after the cut depending on what
   you're testing (a short blip vs. a full cutoff). If you restore power
   before FSD, expect `ONLINE` to fire and cancel the pending sequence —
   confirm this actually happens; `upssched`'s cancellable timers are the
   whole reason this project doesn't reimplement that logic itself.

## Cleanup (order matters)

Only needed if the test reached FSD (the SAI actually cut output or a
secondary shut down).

1. **On RP-node2 first**: `rm -f /etc/killpower`, then
   `systemctl restart nut-driver@apc nut-server nut-monitor`.
2. **Only after step 1 is confirmed healthy**, restart `nut-monitor` on
   the secondaries (Proxmox, RP-node1). Restarting a secondary's
   `nut-monitor` while FSD is still active on the primary makes it shut
   down again and stop polling — this is the exact mistake `CLAUDE.md`
   calls out from prior testing.
3. Verify `upsc apc@localhost ups.status` is `OL` again on every host.
4. Verify `bin/homelab-energy`'s metrics textfile and `state/state.json`
   reflect the sequence you expect (`last_event=ONLINE`, no host stuck
   `in_progress` in `shutdown.sh`'s state if it was exercised).

## If something goes wrong

* A secondary stuck in a shutdown loop: cleanup step 1 (primary first),
  then step 2. Don't restart a secondary's `nut-monitor` before the
  primary is confirmed clean.
* No notification arrived: check `NOTIFICATIONS_ENABLED`, `NTFY_TOPIC`,
  and that `metrics:notify_failed` (via `metrics_collect`) incremented —
  `notify.sh` fails safe and never blocks the shutdown sequence, so a
  dead notification channel never explains a shutdown that didn't happen.
* Proxmox didn't shut down in time: check the SAI's actual
  `ups.delay.shutdown` value (`upsc apc@localhost ups.delay.shutdown`),
  not `HOSTSYNC` — that's the real margin, and it may have drifted from
  the `180` documented in `CLAUDE.md` if the SAI config changed.

## Not yet applicable

NAS integration (TrueNAS as a native NUT secondary, v0.8.0) isn't in this
runbook: there's no NAS in the topology yet. When one exists, it joins
the "Proxmox"/"RP-node1" secondary pattern above — nothing in this repo
needs to change for that, since NAS-side NUT configuration lives on the
NAS itself.
