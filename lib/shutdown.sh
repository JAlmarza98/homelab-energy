#!/usr/bin/env bash

################################################################################
# Configuration
################################################################################

# Safety default (CLAUDE.md): never run a real shutdown command outside an
# explicit, deliberate opt-out of dry-run.
SHUTDOWN_DRY_RUN="${SHUTDOWN_DRY_RUN:-true}"

################################################################################
# Private helpers
################################################################################

_shutdown_state_key() {

    local host="$1"

    printf 'shutdown:%s' "${host}"

}

# Runs "$@" in the background and kills it if it outlives $1 seconds.
# Portable (no GNU `timeout`, which macOS doesn't ship).
_shutdown_run_with_timeout() {

    local timeout="$1"
    shift

    "$@" &
    local cmd_pid=$!

    (
        sleep "${timeout}"
        kill -0 "${cmd_pid}" 2>/dev/null && kill "${cmd_pid}" 2>/dev/null
    ) &
    local watchdog_pid=$!

    local status=0
    wait "${cmd_pid}" || status=$?

    kill "${watchdog_pid}" 2>/dev/null || true
    wait "${watchdog_pid}" 2>/dev/null || true

    return "${status}"

}

################################################################################
# Public API
################################################################################

# idle (never started) is reported as an empty string; call state_load
# first, this only reads the in-memory state.
shutdown_status() {

    local host="$1"

    state_get "$(_shutdown_state_key "${host}")"

}

# Idempotent: starting a shutdown already in_progress or completed is a
# no-op. Only marks intent; shutdown_execute does the actual work.
shutdown_start() {

    local host="$1"
    local current

    current="$(shutdown_status "${host}")"

    case "${current}" in
    in_progress | completed)
        log_info "Shutdown for ${host} already ${current}, skipping"
        return 0
        ;;
    esac

    state_set "$(_shutdown_state_key "${host}")" "in_progress"

}

# Cancellable up until shutdown_execute actually runs the command: once a
# real (non-dry-run) command has started, cancelling can't undo it.
shutdown_cancel() {

    local host="$1"

    state_set "$(_shutdown_state_key "${host}")" "cancelled"

}

# Runs one shutdown stage/command for $host with a timeout. Callers that
# need several stages (e.g. a graceful attempt, then a harder one) call this
# once per stage. Respects a prior shutdown_cancel, and is idempotent: a
# stage already completed is skipped rather than re-run.
shutdown_execute() {

    local host="$1"
    local command="$2"
    local timeout="${3:-30}"

    local status
    status="$(shutdown_status "${host}")"

    case "${status}" in
    cancelled)
        log_info "Shutdown for ${host} was cancelled, not executing"
        return 1
        ;;
    completed)
        log_info "Shutdown for ${host} already completed, skipping"
        return 0
        ;;
    esac

    if [[ "${SHUTDOWN_DRY_RUN}" == true ]]; then
        log_info "[dry-run] would run on ${host} (timeout ${timeout}s): ${command}"
        return 0
    fi

    log_info "Shutting down ${host} (timeout ${timeout}s): ${command}"

    if _shutdown_run_with_timeout "${timeout}" bash -c "${command}"; then
        state_set "$(_shutdown_state_key "${host}")" "completed"
        return 0
    fi

    state_set "$(_shutdown_state_key "${host}")" "failed"
    log_warn "Shutdown command failed or timed out for ${host}"
    return 1

}
