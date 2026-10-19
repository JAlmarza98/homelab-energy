#!/usr/bin/env bash

################################################################################
# Core
################################################################################

# A notification failure must never block or delay a shutdown: this always
# returns 0, and every step that can fail is itself guarded so set -e in the
# caller (bootstrap.sh) can never abort on it.
_notify_send() {

    local emoji="$1"
    local message="$2"

    [[ "${NOTIFICATIONS_ENABLED:-false}" == true ]] || return 0

    command -v curl >/dev/null 2>&1 || {
        log_warn "curl not available, cannot send notification"
        return 0
    }

    local token="${TELEGRAM_BOT_TOKEN:-}"
    local chat_id="${TELEGRAM_CHAT_ID:-}"

    [[ -n "${token}" && -n "${chat_id}" ]] || {
        log_warn "TELEGRAM_BOT_TOKEN/TELEGRAM_CHAT_ID not set, skipping notification"
        return 0
    }

    local url="https://api.telegram.org/bot${token}/sendMessage"
    local text="${emoji} ${PROJECT_NAME:-homelab-energy}: ${message}"

    if curl --silent --show-error --fail --max-time 5 \
        --data-urlencode "chat_id=${chat_id}" \
        --data-urlencode "text=${text}" \
        "${url}" >/dev/null 2>&1; then
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

    _notify_send "ℹ️" "$1"

}

notify_success() {

    _notify_send "✅" "$1"

}

notify_warning() {

    _notify_send "⚠️" "$1"

}

notify_error() {

    _notify_send "🚨" "$1"

}
