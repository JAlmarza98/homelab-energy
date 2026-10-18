#!/usr/bin/env bash

################################################################################
# Configuration
################################################################################

readonly LOG_LEVEL_DEBUG=10
readonly LOG_LEVEL_INFO=20
readonly LOG_LEVEL_SUCCESS=25
readonly LOG_LEVEL_WARN=30
readonly LOG_LEVEL_ERROR=40

LOGGER_LEVEL="${LOG_LEVEL_INFO}"

LOGGER_HANDLER_CONSOLE=true
LOGGER_HANDLER_FILE=false
LOGGER_HANDLER_JOURNALD=false

LOGGER_FILE_PATH="${PROJECT_ROOT:-.}/logs/energy.log"

################################################################################
# Colors
################################################################################

readonly LOGGER_COLOR_RESET="\033[0m"

readonly LOGGER_COLOR_DEBUG="\033[0;90m"
readonly LOGGER_COLOR_INFO="\033[0;34m"
readonly LOGGER_COLOR_SUCCESS="\033[0;32m"
readonly LOGGER_COLOR_WARN="\033[0;33m"
readonly LOGGER_COLOR_ERROR="\033[0;31m"

################################################################################
# Public API
################################################################################

# Sets LOGGER_LEVEL from a level name (e.g. config's LOG_LEVEL=INFO).
logger_set_level() {

    local name="$1"

    case "${name}" in
    DEBUG) LOGGER_LEVEL="${LOG_LEVEL_DEBUG}" ;;
    INFO) LOGGER_LEVEL="${LOG_LEVEL_INFO}" ;;
    SUCCESS) LOGGER_LEVEL="${LOG_LEVEL_SUCCESS}" ;;
    WARN) LOGGER_LEVEL="${LOG_LEVEL_WARN}" ;;
    ERROR) LOGGER_LEVEL="${LOG_LEVEL_ERROR}" ;;
    *)
        echo "Unknown log level: ${name}" >&2
        return 1
        ;;
    esac

}

log_debug() {

    _logger_log \
        "${LOG_LEVEL_DEBUG}" \
        "DEBUG" \
        "$1"

}

log_info() {

    _logger_log \
        "${LOG_LEVEL_INFO}" \
        "INFO" \
        "$1"

}

log_success() {

    _logger_log \
        "${LOG_LEVEL_SUCCESS}" \
        "SUCCESS" \
        "$1"

}

log_warn() {

    _logger_log \
        "${LOG_LEVEL_WARN}" \
        "WARN" \
        "$1"

}

log_error() {

    _logger_log \
        "${LOG_LEVEL_ERROR}" \
        "ERROR" \
        "$1"

}

################################################################################
# Core
################################################################################

_logger_log() {

    local level="$1"
    local label="$2"
    local text="$3"

    _logger_should_log "${level}" || return 0

    local timestamp

    timestamp="$(_logger_timestamp)"

    _logger_dispatch \
        "${timestamp}" \
        "${level}" \
        "${label}" \
        "${text}"

}

################################################################################
# Dispatcher
################################################################################

# Dispatches a log record to all enabled handlers.
#
# A handler is responsible only for writing the message to its destination.
# Formatting is delegated to formatter functions.

_logger_dispatch() {

    local timestamp="$1"
    local level="$2"
    local label="$3"
    local text="$4"

    if [[ "${LOGGER_HANDLER_CONSOLE}" == true ]]; then

        _logger_console \
            "${timestamp}" \
            "${level}" \
            "${label}" \
            "${text}"

    fi

    if [[ "${LOGGER_HANDLER_FILE}" == true ]]; then

        _logger_file \
            "${timestamp}" \
            "${label}" \
            "${text}"

    fi

    if [[ "${LOGGER_HANDLER_JOURNALD}" == true ]]; then

        _logger_journald \
            "${timestamp}" \
            "${level}" \
            "${label}" \
            "${text}"

    fi

}

################################################################################
# Utilities
################################################################################

_logger_should_log() {

    local level="$1"

    ((level >= LOGGER_LEVEL))

}

_logger_timestamp() {

    date '+%Y-%m-%d %H:%M:%S'

}

_logger_color() {

    local level="$1"

    case "${level}" in

    "${LOG_LEVEL_DEBUG}")
        printf "%b" "${LOGGER_COLOR_DEBUG}"
        ;;

    "${LOG_LEVEL_INFO}")
        printf "%b" "${LOGGER_COLOR_INFO}"
        ;;

    "${LOG_LEVEL_SUCCESS}")
        printf "%b" "${LOGGER_COLOR_SUCCESS}"
        ;;

    "${LOG_LEVEL_WARN}")
        printf "%b" "${LOGGER_COLOR_WARN}"
        ;;

    "${LOG_LEVEL_ERROR}")
        printf "%b" "${LOGGER_COLOR_ERROR}"
        ;;

    *)
        printf "%b" "${LOGGER_COLOR_RESET}"
        ;;

    esac

}

################################################################################
# Formatters
################################################################################

_logger_plain_format() {

    local timestamp="$1"
    local label="$2"
    local text="$3"

    printf "%s %-8s %s" \
        "${timestamp}" \
        "${label}" \
        "${text}"

}

_logger_console_format() {

    local timestamp="$1"
    local level="$2"
    local label="$3"
    local text="$4"

    local formatted

    printf -v formatted \
        "%s %-8s %s" \
        "${timestamp}" \
        "${label}" \
        "${text}"

    printf "%b%s%b" \
        "$(_logger_color "${level}")" \
        "${formatted}" \
        "${LOGGER_COLOR_RESET}"

}

################################################################################
# Handlers
################################################################################

_logger_console() {

    local timestamp="$1"
    local level="$2"
    local label="$3"
    local text="$4"

    local output

    output="$(
        _logger_console_format \
            "${timestamp}" \
            "${level}" \
            "${label}" \
            "${text}"
    )"

    printf "%s\n" "${output}"

}

_logger_file() {

    local timestamp="$1"
    local label="$2"
    local text="$3"

    local output

    output="$(
        _logger_plain_format \
            "${timestamp}" \
            "${label}" \
            "${text}"
    )"

    mkdir -p "$(dirname "${LOGGER_FILE_PATH}")"

    printf "%s\n" "${output}" >>"${LOGGER_FILE_PATH}"

}

_logger_journald() {

    # TODO:
    # Implement journald handler using systemd-cat.
    #
    # This handler should:
    #   - Preserve log level.
    #   - Avoid ANSI color codes.
    #   - Integrate with journalctl.
    #
    return 0

}
