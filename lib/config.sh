#!/usr/bin/env bash

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

CONFIG_DIR="${CONFIG_DIR:-${PROJECT_ROOT}/config}"

DEFAULTS_CONFIG="${CONFIG_DIR}/defaults.conf"

ENERGY_CONFIG="${CONFIG_DIR}/energy.conf"

HOSTS_CONFIG="${CONFIG_DIR}/hosts/$(hostname).conf"

# Secrets never live in Git: a local dev override (gitignored) or the
# production path with restricted permissions.
SECRETS_CONFIG_LOCAL="${SECRETS_CONFIG_LOCAL:-${PROJECT_ROOT}/.env}"

SECRETS_CONFIG_SYSTEM="${SECRETS_CONFIG_SYSTEM:-/etc/homelab-energy/secrets.env}"

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

_config_mode() {

    local file="$1"

    stat -c '%a' "${file}" 2>/dev/null || stat -f '%Lp' "${file}" 2>/dev/null

}

# Refuses to load a secrets file that is readable by group/others, so a
# misconfigured secrets.env cannot leak NUT passwords or notification
# tokens to other local users.
_config_require_private() {

    local file="$1"
    local mode

    mode="$(_config_mode "${file}")"

    [[ "${mode: -2}" == "00" ]] || {
        echo "Refusing to load ${file}: must not be readable by group/others (chmod 600)" >&2
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

    if [[ -f "${SECRETS_CONFIG_LOCAL}" ]]; then
        _config_require_private "${SECRETS_CONFIG_LOCAL}"
        _config_parse_file "${SECRETS_CONFIG_LOCAL}"
    fi

    if [[ -f "${SECRETS_CONFIG_SYSTEM}" ]]; then
        _config_require_private "${SECRETS_CONFIG_SYSTEM}"
        _config_parse_file "${SECRETS_CONFIG_SYSTEM}"
    fi

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
