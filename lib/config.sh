#!/usr/bin/env bash

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

CONFIG_DIR="${CONFIG_DIR:-${PROJECT_ROOT}/config}"

DEFAULTS_CONFIG="${CONFIG_DIR}/defaults.conf"

ENERGY_CONFIG="${CONFIG_DIR}/energy.conf"

HOSTS_CONFIG="${CONFIG_DIR}/hosts/$(hostname).conf"

################################################################################
# Private helpers
################################################################################

# Parses a CLAVE=valor file into global variables. Never sources it, so a
# config file cannot execute arbitrary shell code.
_config_parse_file() {

    local file="$1"
    local key
    local value

    while IFS='=' read -r key value; do

        key="${key%%#*}"
        key="${key#"${key%%[![:space:]]*}"}"
        key="${key%"${key##*[![:space:]]}"}"

        [[ -z "${key}" ]] && continue

        [[ "${key}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue

        value="${value%%#*}"
        value="${value#"${value%%[![:space:]]*}"}"
        value="${value%"${value##*[![:space:]]}"}"

        printf -v "${key}" '%s' "${value}"

    done <"${file}"

}

_config_require_int() {

    local key="$1"
    local value="${!key-}"

    [[ "${value}" =~ ^[0-9]+$ ]] || {
        echo "Invalid config: ${key} must be an integer (got '${value}')" >&2
        exit 1
    }

}

_config_require_bool() {

    local key="$1"
    local value="${!key-}"

    case "${value}" in
    true | false) ;;
    *)
        echo "Invalid config: ${key} must be true or false (got '${value}')" >&2
        exit 1
        ;;
    esac

}

_config_validate() {

    _config_require_int SHUTDOWN_DELAY

    _config_require_bool PROXMOX_ENABLED
    _config_require_bool NAS_ENABLED
    _config_require_bool NOTIFICATIONS_ENABLED
    _config_require_bool PROMETHEUS_ENABLED

}

################################################################################
# Public API
################################################################################

load_config() {

    [[ -f "${DEFAULTS_CONFIG}" ]] || {
        echo "Missing defaults.conf" >&2
        exit 1
    }

    _config_parse_file "${DEFAULTS_CONFIG}"

    [[ -f "${ENERGY_CONFIG}" ]] && _config_parse_file "${ENERGY_CONFIG}"

    [[ -f "${HOSTS_CONFIG}" ]] && _config_parse_file "${HOSTS_CONFIG}"

    _config_validate

}

reload_config() {

    load_config

}

config_get() {

    local key="$1"

    printf '%s' "${!key-}"

}

config_exists() {

    local key="$1"

    [[ -n "${!key+x}" ]]

}
