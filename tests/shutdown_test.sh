#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

source "${PROJECT_ROOT}/lib/test.sh"

test_init "Shutdown"

################################################################################
# Fixtures: isolated state dir, logger silenced, never touches real hosts.
################################################################################

TEST_STATE_DIR="${PROJECT_ROOT}/tests/tmp/shutdown-state"
MARKER="${PROJECT_ROOT}/tests/tmp/shutdown-marker"

rm -rf "${TEST_STATE_DIR}"
rm -f "${MARKER}"

export PROJECT_ROOT
export STATE_DIR="${TEST_STATE_DIR}"

source "${PROJECT_ROOT}/lib/utils.sh"
source "${PROJECT_ROOT}/lib/logger.sh"

LOGGER_HANDLER_CONSOLE=false

source "${PROJECT_ROOT}/lib/state.sh"
source "${PROJECT_ROOT}/lib/shutdown.sh"

state_load

################################################################################
# Idle / start / idempotency
################################################################################

assert_equals \
    "an untouched host is idle (empty status)" \
    "" \
    "$(shutdown_status switch1)"

shutdown_start switch1

assert_equals \
    "shutdown_start marks the host in_progress" \
    "in_progress" \
    "$(shutdown_status switch1)"

shutdown_start switch1

assert_equals \
    "a second shutdown_start is a no-op" \
    "in_progress" \
    "$(shutdown_status switch1)"

################################################################################
# Dry-run (the default): never actually runs the command
################################################################################

assert_equals \
    "SHUTDOWN_DRY_RUN defaults to true" \
    "true" \
    "${SHUTDOWN_DRY_RUN}"

assert_success \
    "dry-run execute reports success without acting" \
    shutdown_execute switch1 "touch '${MARKER}'" 5

assert_false \
    "dry-run never creates the marker" \
    test -f "${MARKER}"

assert_equals \
    "dry-run does not change status" \
    "in_progress" \
    "$(shutdown_status switch1)"

################################################################################
# Real execution: success
################################################################################

SHUTDOWN_DRY_RUN=false

assert_success \
    "a real successful command reports success" \
    shutdown_execute switch1 "touch '${MARKER}'" 5

assert_true \
    "a real successful command actually runs" \
    test -f "${MARKER}"

assert_equals \
    "a successful execute marks the host completed" \
    "completed" \
    "$(shutdown_status switch1)"

rm -f "${MARKER}"

assert_success \
    "re-running execute on a completed host is a no-op" \
    shutdown_execute switch1 "touch '${MARKER}'" 5

assert_false \
    "the no-op re-run does not touch the host again" \
    test -f "${MARKER}"

################################################################################
# Real execution: failure and timeout
################################################################################

assert_false \
    "a failing command reports failure" \
    shutdown_execute switch2 "exit 1" 5

assert_equals \
    "a failing command marks the host failed" \
    "failed" \
    "$(shutdown_status switch2)"

assert_false \
    "a command that outlives its timeout reports failure" \
    shutdown_execute switch3 "sleep 5" 1

assert_equals \
    "a timed-out command marks the host failed" \
    "failed" \
    "$(shutdown_status switch3)"

# A retry after a failure is allowed (not blocked like "completed" is).
assert_success \
    "a retry after failure is allowed" \
    shutdown_execute switch2 "exit 0" 5

assert_equals \
    "the retry marks the host completed" \
    "completed" \
    "$(shutdown_status switch2)"

################################################################################
# Cancellation
################################################################################

shutdown_start switch4
shutdown_cancel switch4

assert_equals \
    "shutdown_cancel marks the host cancelled" \
    "cancelled" \
    "$(shutdown_status switch4)"

assert_false \
    "a cancelled host refuses to execute" \
    shutdown_execute switch4 "touch '${MARKER}'" 5

assert_false \
    "a cancelled host's command never runs" \
    test -f "${MARKER}"

################################################################################
# Cleanup
################################################################################

rm -rf "${TEST_STATE_DIR}"
rm -f "${MARKER}"

test_summary
