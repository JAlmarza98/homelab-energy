#!/usr/bin/env bash

set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

CONFIG_DIR="${PROJECT_ROOT}/config"

ENERGY_CONFIG="${CONFIG_DIR}/energy.conf"

HOSTS_CONFIG="${CONFIG_DIR}/hosts.conf"

load_config() {

    [[ -f "$ENERGY_CONFIG" ]] || {
        echo "Missing energy.conf"
        exit 1
    }

    [[ -f "$HOSTS_CONFIG" ]] || {
        echo "Missing hosts.conf"
        exit 1
    }

    # shellcheck disable=SC1090
    source "$ENERGY_CONFIG"

    # shellcheck disable=SC1090
    source "$HOSTS_CONFIG"

}
