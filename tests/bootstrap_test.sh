#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

source "${PROJECT_ROOT}/lib/test.sh"

test_init "Bootstrap"

source "${PROJECT_ROOT}/lib/bootstrap.sh"

assert_success \
    "bootstrap runs against the real project config" \
    bootstrap

assert_equals \
    "bootstrap loads the real site config" \
    "apc" \
    "$(config_get UPS_NAME)"

assert_equals \
    "bootstrap maps LOG_LEVEL to LOGGER_LEVEL" \
    "${LOG_LEVEL_INFO}" \
    "${LOGGER_LEVEL}"

test_summary
