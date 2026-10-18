#!/usr/bin/env bash

################################################################################
# Configuration
################################################################################

NTFY_URL_DEFAULT="https://ntfy.sh"

################################################################################
# Core
################################################################################

# A notification failure must never block or delay a shutdown: this always
# returns 0, and every step that can fail is itself guarded so set -e in the
# caller (bootstrap.sh) can never abort on it.
_notify_send() {

    local priority="$1"
    local tags="$2"
    local message="$3"

    [[ "${NOTIFICATIONS_ENABLED:-false}" == true ]] || return 0

    command -v curl >/dev/null 2>&1 || {
        log_warn "curl not available, cannot send notification"
        return 0
    }

    local topic="${NTFY_TOPIC:-}"

    [[ -n "${topic}" ]] || {
        log_warn "NTFY_TOPIC not set, skipping notification"
        return 0
    }

    local url="${NTFY_URL:-${NTFY_URL_DEFAULT}}/${topic}"

    local -a curl_args=(
        --silent --show-error --fail --max-time 5
        -H "Title: ${PROJECT_NAME:-homelab-energy}"
        -H "Priority: ${priority}"
        -H "Tags: ${tags}"
        -d "${message}"
    )

    [[ -n "${NTFY_TOKEN:-}" ]] && curl_args+=(-H "Authorization: Bearer ${NTFY_TOKEN}")

    if curl "${curl_args[@]}" "${url}" >/dev/null 2>&1; then
        metrics_increment notify_sent
    else
        metrics_increment notify_failed
        log_warn "Failed to send notification: ${message}"
    fi

    return 0

}

################################################################################
# Public API
################################################################################

notify_info() {

    _notify_send "default" "information_source" "$1"

}

notify_success() {

    _notify_send "default" "white_check_mark" "$1"

}

notify_warning() {

    _notify_send "high" "warning" "$1"

}

notify_error() {

    _notify_send "urgent" "rotating_light" "$1"

}
