#!/usr/bin/env bash

set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "${PROJECT_ROOT}/lib/utils.sh"
source "${PROJECT_ROOT}/lib/logger.sh"
source "${PROJECT_ROOT}/lib/config.sh"
source "${PROJECT_ROOT}/lib/nut.sh"
source "${PROJECT_ROOT}/lib/notify.sh"
source "${PROJECT_ROOT}/lib/state.sh"

################################################################################
# Public API
################################################################################

bootstrap() {

    require_command bash date mkdir hostname || {
        echo "Missing required commands" >&2
        exit 1
    }

    load_config

    logger_set_level "$(config_get LOG_LEVEL)" || {
        echo "Invalid LOG_LEVEL in config" >&2
        exit 1
    }

}
