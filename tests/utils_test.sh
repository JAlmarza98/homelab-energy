#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

source "${PROJECT_ROOT}/lib/utils.sh"
source "${PROJECT_ROOT}/lib/test.sh"

test_init "Utils"

assert_command bash
assert_command date
assert_command mkdir

assert_success \
    "require_command" \
    require_command bash date mkdir

assert_true \
    "README exists" \
    file_exists "${PROJECT_ROOT}/README.md"

assert_true \
    "lib exists" \
    directory_exists "${PROJECT_ROOT}/lib"

TEST_DIR="${PROJECT_ROOT}/tests/tmp"

rm -rf "${TEST_DIR}"

ensure_directory "${TEST_DIR}"

assert_true \
    "ensure_directory" \
    directory_exists "${TEST_DIR}"

rm -rf "${TEST_DIR}"

assert_true \
    "timestamp_now" \
    test -n "$(timestamp_now)"

assert_true \
    "timestamp_iso8601" \
    test -n "$(timestamp_iso8601)"

assert_true \
    "timestamp_epoch" \
    test -n "$(timestamp_epoch)"

test_summary
