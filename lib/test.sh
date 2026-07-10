#!/usr/bin/env bash

set -Eeuo pipefail

################################################################################
# Test counters
################################################################################

TEST_TOTAL=0
TEST_PASSED=0
TEST_FAILED=0

################################################################################
# Colors
################################################################################

readonly GREEN="\033[0;32m"
readonly RED="\033[0;31m"
readonly BLUE="\033[0;34m"
readonly RESET="\033[0m"

readonly ICON_PASS="✓"
readonly ICON_FAIL="✗"
readonly ICON_INFO="•"

################################################################################
# Private helpers
################################################################################

_test_print_result() {

    local result="$1"
    local name="$2"

    case "${result}" in
    PASS)
        printf "${GREEN}%s${RESET} %s\n" "${ICON_PASS}" "${name}"
        ;;

    FAIL)
        printf "${RED}%s${RESET} %s\n" "${ICON_FAIL}" "${name}"
        ;;

    *)
        printf "${BLUE}%s${RESET} %s\n" "${ICON_INFO}" "${name}"
        ;;

    esac

}

################################################################################
# Test suite
################################################################################

test_init() {

    local suite="$1"

    echo
    echo "========================================="
    echo " ${suite} Test Suite"
    echo "========================================="
    echo

}

################################################################################
# Assertions
################################################################################

assert_success() {

    local name="$1"
    shift

    ((++TEST_TOTAL))

    if "$@"; then
        ((++TEST_PASSED))
        _test_print_result PASS "${name}"
    else
        ((++TEST_FAILED))
        _test_print_result FAIL "${name}"
    fi

}

assert_true() {

    assert_success "$@"

}

assert_command() {

    local command="$1"

    assert_success \
        "command '${command}' exists" \
        command_exists "${command}"

}

assert_false() {

    local name="$1"
    shift

    ((++TEST_TOTAL))

    if "$@"; then
        ((++TEST_PASSED))
        _test_print_result PASS "${name}"
    else
        ((++TEST_FAILED))
        _test_print_result FAIL "${name}"
    fi

}

assert_equals() {

    local name="$1"
    local expected="$2"
    local actual="$3"

    ((++TEST_TOTAL))

    if [[ "${expected}" == "${actual}" ]]; then
        ((++TEST_PASSED))
        _test_print_result PASS "${name}"
    else
        ((++TEST_FAILED))
        _test_print_result FAIL "${name}"
        echo "    Expected : ${expected}"
        echo "    Actual   : ${actual}"
    fi

}

################################################################################
# Summary
################################################################################

test_summary() {

    echo
    echo "-----------------------------------------"
    printf "Tests : %d\n" "${TEST_TOTAL}"
    printf "Passed: %d\n" "${TEST_PASSED}"
    printf "Failed: %d\n" "${TEST_FAILED}"
    echo "-----------------------------------------"
    echo

    if [[ ${TEST_FAILED} -eq 0 ]]; then
        printf "${GREEN}%s All tests passed.${RESET}\n" "${ICON_PASS}"
        return 0
    fi

    printf "${RED}%s Some tests failed.${RESET}\n" "${ICON_FAIL}"
    return 1

}
