#!/usr/bin/env bash

################################################################################
# Configuration
################################################################################

# node_exporter's textfile collector directory (production default). Point
# METRICS_FILE elsewhere for local/dev use.
METRICS_FILE="${METRICS_FILE:-/var/lib/node_exporter/textfile_collector/homelab_energy.prom}"

################################################################################
# Private helpers
################################################################################

_metrics_state_key() {

    local name="$1"

    printf 'metrics:%s' "${name}"

}

_metrics_shutdown_status_code() {

    case "$1" in
    "") echo 0 ;;
    in_progress) echo 1 ;;
    completed) echo 2 ;;
    failed) echo 3 ;;
    cancelled) echo 4 ;;
    *) echo -1 ;;
    esac

}

################################################################################
# Public API
################################################################################

# Sets a gauge-like value (e.g. the last NUT event name/timestamp).
# Persisted via state.sh: call state_load first, state_save to flush.
metrics_update() {

    local name="$1"
    local value="$2"

    state_set "$(_metrics_state_key "${name}")" "${value}"

}

# Increments a counter by 1 (e.g. notifications sent/failed). Same
# state.sh-backed persistence as metrics_update.
metrics_increment() {

    local name="$1"
    local current

    current="$(state_get "$(_metrics_state_key "${name}")")"

    [[ "${current}" =~ ^[0-9]+$ ]] || current=0

    state_set "$(_metrics_state_key "${name}")" "$((current + 1))"

}

# Prints the current metrics in Prometheus text exposition format. Reads
# from the in-memory STATE_JSON (call state_load first); never queries
# upsc/curl/ssh itself, it only reports what other modules already recorded.
metrics_collect() {

    local last_event last_event_at notify_sent notify_failed

    last_event="$(state_get "$(_metrics_state_key last_event)")"
    last_event_at="$(state_get "$(_metrics_state_key last_event_at)")"
    notify_sent="$(state_get "$(_metrics_state_key notify_sent)")"
    notify_failed="$(state_get "$(_metrics_state_key notify_failed)")"

    echo "# HELP homelab_energy_last_event_timestamp Unix timestamp of the last NUT event handled."
    echo "# TYPE homelab_energy_last_event_timestamp gauge"
    [[ -n "${last_event_at}" ]] &&
        printf 'homelab_energy_last_event_timestamp{event="%s"} %s\n' "${last_event}" "${last_event_at}"

    echo "# HELP homelab_energy_notifications_sent_total Notifications successfully sent via notify.sh."
    echo "# TYPE homelab_energy_notifications_sent_total counter"
    printf 'homelab_energy_notifications_sent_total %s\n' "${notify_sent:-0}"

    echo "# HELP homelab_energy_notifications_failed_total Notifications that failed to send via notify.sh."
    echo "# TYPE homelab_energy_notifications_failed_total counter"
    printf 'homelab_energy_notifications_failed_total %s\n' "${notify_failed:-0}"

    echo "# HELP homelab_energy_shutdown_status shutdown.sh status per host: 0=idle 1=in_progress 2=completed 3=failed 4=cancelled."
    echo "# TYPE homelab_energy_shutdown_status gauge"

    local host
    while IFS= read -r host; do
        [[ -n "${host}" ]] || continue
        printf 'homelab_energy_shutdown_status{host="%s"} %s\n' \
            "${host}" "$(_metrics_shutdown_status_code "$(state_get "shutdown:${host}")")"
    done < <(jq -r 'keys[] | select(startswith("shutdown:")) | sub("^shutdown:"; "")' <<<"${STATE_JSON}")

}

# Writes metrics_collect's output to METRICS_FILE atomically (tmp + mv),
# same pattern as state_save. World-readable: node_exporter's textfile
# collector almost always runs as a different, unrelated user from
# whoever calls this (e.g. NUT's notify user), and mktemp's default mode
# (600, owner-only) would otherwise make the file unreadable to it.
metrics_export() {

    local dir
    dir="$(dirname "${METRICS_FILE}")"

    ensure_directory "${dir}"

    local tmp
    tmp="$(mktemp "${dir}/.homelab_energy.XXXXXX")"

    metrics_collect >"${tmp}"
    chmod 644 "${tmp}"
    mv "${tmp}" "${METRICS_FILE}"

}
