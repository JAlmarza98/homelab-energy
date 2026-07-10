#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "${SCRIPT_DIR}")")"

source "${PROJECT_ROOT}/lib/test.sh"
source "${PROJECT_ROOT}/lib/logger.sh"

test_init "Logger API"

################################################################################
# INFO
################################################################################

LOGGER_LEVEL="${LOG_LEVEL_INFO}"

OUTPUT="$(log_info "Hello World")"

assert_true \
    "INFO appears" \
    grep -q "INFO" <<<"${OUTPUT}"

assert_true \
    "Message appears" \
    grep -q "Hello World" <<<"${OUTPUT}"

################################################################################
# LEVEL FILTER
################################################################################

LOGGER_LEVEL="${LOG_LEVEL_WARN}"

OUTPUT="$(log_info "Hidden")"

assert_equals \
    "INFO filtered" \
    "" \
    "${OUTPUT}"

OUTPUT="$(log_error "Visible")"

assert_true \
    "ERROR visible" \
    grep -q "ERROR" <<<"${OUTPUT}"

################################################################################
# SUMMARY
################################################################################

test_summary
