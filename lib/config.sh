#!/usr/bin/env bash

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

CONFIG_DIR="${PROJECT_ROOT}/config"

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

################################################################################
# Public API
################################################################################

load_config() {

    [[ -f "${ENERGY_CONFIG}" ]] || {
        echo "Missing energy.conf"
        exit 1
    }

    [[ -f "${HOSTS_CONFIG}" ]] || {
        echo "Missing host config: ${HOSTS_CONFIG}"
        exit 1
    }

    _config_parse_file "${ENERGY_CONFIG}"
    _config_parse_file "${HOSTS_CONFIG}"

}
