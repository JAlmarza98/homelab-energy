#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "${SCRIPT_DIR}")")"

source "${PROJECT_ROOT}/lib/test.sh"
source "${PROJECT_ROOT}/lib/logger.sh"

test_init "Logger Handlers"

################################################################################
# FILE HANDLER
################################################################################

LOGGER_LEVEL="${LOG_LEVEL_INFO}"

LOGGER_HANDLER_FILE=true
LOGGER_HANDLER_CONSOLE=false
LOGGER_FILE_PATH="/tmp/logger_test.log"

rm -f "${LOGGER_FILE_PATH}"

log_info "Written to file"

assert_true \
    "Log file created" \
    test -f "${LOGGER_FILE_PATH}"

assert_true \
    "Log written to file" \
    grep -q "Written to file" "${LOGGER_FILE_PATH}"

rm -f "${LOGGER_FILE_PATH}"

LOGGER_HANDLER_FILE=false
LOGGER_HANDLER_CONSOLE=true

################################################################################
# SUMMARY
################################################################################

test_summary
