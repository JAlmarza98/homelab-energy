#!/usr/bin/env bash

################################################################################
# Configuration
################################################################################

STATE_DIR="${STATE_DIR:-${PROJECT_ROOT}/state}"

STATE_FILE="${STATE_DIR}/state.json"

STATE_LOCK="${STATE_DIR}/state.lock"

# Fixed fd (not bash's {fd}-auto-allocation, which needs bash 4+) used to
# flock STATE_LOCK. Only state_load/state_save hold it, briefly.
STATE_LOCK_FD=200

STATE_LOCK_WAIT="${STATE_LOCK_WAIT:-5}"

# In-memory copy of the state JSON, populated by state_load. state_get/set/
# delete/exists only touch this string; state_save is what persists it.
STATE_JSON="{}"

################################################################################
# Private helpers
################################################################################

_state_require_jq() {

    command -v jq >/dev/null 2>&1 || {
        echo "jq is required by state.sh" >&2
        return 1
    }

}

_state_lock() {

    eval "exec ${STATE_LOCK_FD}>\"\${STATE_LOCK}\""

    flock -x -w "${STATE_LOCK_WAIT}" "${STATE_LOCK_FD}" || {
        echo "Could not acquire state lock: ${STATE_LOCK}" >&2
        return 1
    }

}

_state_unlock() {

    flock -u "${STATE_LOCK_FD}"

    eval "exec ${STATE_LOCK_FD}>&-"

}

################################################################################
# Public API
################################################################################

state_load() {

    _state_require_jq || return 1

    ensure_directory "${STATE_DIR}"

    [[ -f "${STATE_FILE}" ]] || printf '{}' >"${STATE_FILE}"

    _state_lock || return 1

    STATE_JSON="$(cat "${STATE_FILE}")"

    _state_unlock

}

state_save() {

    _state_require_jq || return 1

    ensure_directory "${STATE_DIR}"

    _state_lock || return 1

    local tmp
    tmp="$(mktemp "${STATE_DIR}/.state.XXXXXX")"

    printf '%s' "${STATE_JSON}" >"${tmp}"
    mv "${tmp}" "${STATE_FILE}"

    _state_unlock

}

state_get() {

    local key="$1"

    _state_require_jq || return 1

    jq -r --arg k "${key}" '.[$k] // empty' <<<"${STATE_JSON}"

}

state_set() {

    local key="$1"
    local value="$2"

    _state_require_jq || return 1

    STATE_JSON="$(jq --arg k "${key}" --arg v "${value}" '.[$k] = $v' <<<"${STATE_JSON}")"

}

state_delete() {

    local key="$1"

    _state_require_jq || return 1

    STATE_JSON="$(jq --arg k "${key}" 'del(.[$k])' <<<"${STATE_JSON}")"

}

state_exists() {

    local key="$1"
    local result

    _state_require_jq || return 1

    result="$(jq -r --arg k "${key}" 'has($k)' <<<"${STATE_JSON}")"

    [[ "${result}" == "true" ]]

}
