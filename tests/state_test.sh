#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

source "${PROJECT_ROOT}/lib/test.sh"

test_init "State"

################################################################################
# Fixtures: an isolated state dir, never the real state/ directory.
################################################################################

TEST_STATE_DIR="${PROJECT_ROOT}/tests/tmp/state"

rm -rf "${TEST_STATE_DIR}"

export PROJECT_ROOT
export STATE_DIR="${TEST_STATE_DIR}"

source "${PROJECT_ROOT}/lib/utils.sh"
source "${PROJECT_ROOT}/lib/state.sh"

################################################################################
# state_load bootstraps an empty state file
################################################################################

assert_success \
    "state_load succeeds on a missing state dir" \
    state_load

assert_true \
    "state_load creates state.json" \
    test -f "${STATE_DIR}/state.json"

assert_equals \
    "a fresh state file is an empty object" \
    "{}" \
    "${STATE_JSON}"

################################################################################
# get / set / exists / delete on the in-memory copy
################################################################################

assert_false \
    "state_exists false for an unset key" \
    state_exists last_event

state_set last_event ONBATT

assert_success \
    "state_exists true after state_set" \
    state_exists last_event

assert_equals \
    "state_get returns the value just set" \
    "ONBATT" \
    "$(state_get last_event)"

state_delete last_event

assert_false \
    "state_exists false after state_delete" \
    state_exists last_event

assert_equals \
    "state_get empty for a deleted key" \
    "" \
    "$(state_get last_event)"

################################################################################
# state_save persists to disk atomically, state_load reads it back
################################################################################

state_set last_event LOWBATT
state_set last_event_at "2026-01-01T00:00:00"

assert_success \
    "state_save writes the state file" \
    state_save

assert_true \
    "the persisted file is valid JSON" \
    jq -e . "${STATE_DIR}/state.json" >/dev/null

STATE_JSON="{}"

state_load

assert_equals \
    "state_load reads back a previously saved value" \
    "LOWBATT" \
    "$(state_get last_event)"

################################################################################
# A held lock blocks a concurrent state_save until it times out
################################################################################

ensure_directory "${STATE_DIR}"

(
    exec 201>"${STATE_DIR}/state.lock"
    flock -x 201
    sleep 2
) &
HOLDER_PID=$!

sleep 0.3

# -w 0 means something different between util-linux flock and the
# discoteq/flock used on macOS, so use a short positive wait instead.
STATE_LOCK_WAIT=1

assert_false \
    "state_save fails while the lock is held" \
    state_save

wait "${HOLDER_PID}"

STATE_LOCK_WAIT=5

assert_success \
    "state_save succeeds once the lock is released" \
    state_save

################################################################################
# Cleanup
################################################################################

rm -rf "${TEST_STATE_DIR}"

test_summary
